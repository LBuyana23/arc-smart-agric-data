import json
from paho.mqtt import client as mqtt
import http.client


# --- MQTT Broker Configuration ---
BROKER = "localhost"
PORT = 1883

# --- Sensor group to table mapping ---
SENSOR_GROUP_MAP = {
    "soil-sensor": [
        {"group_id": 7, "table": "soil_table"},
        {"group_id": 8, "table": "soil_table"},
        {"group_id": 10, "table": "soil_table"}
    ],
    "water-sensor": [
        {"group_id": 2, "table": "water_table"},
        {"group_id": 6, "table": "water_table"}
    ],
    "Crop-sensor": [
        {"group_id": 5, "table": "Crop_table"},
        {"group_id": 4, "table": "Crop_table"}
    ],
    "Greenhouse-sensor": [
        {"group_id": 1, "table": "Greenhouse_table1"},
        {"group_id": 9, "table": "Greenhouse_table9"}
    ]
}

# --- MQTT Topics ---
MQTT_TOPICS = [
    ("arc/soil-monitoring/group7/soil-sensor", 0),
    ("arc/soil-monitoring/group8/soil-sensor", 0),
    ("arc/soil-monitoring/group10/soil-sensor", 0),
    ("arc/water-monitoring/group2/water-sensor", 0),
    ("arc/water-monitoring/group6/water-sensor", 0),
    ("arc/Crop-monitoring/group5/Crop-sensor", 0),
    ("arc/Crop-monitoring/group4/Crop-sensor", 0),
    ("arc/Greenhouse-monitoring/group1/Greenhouse-sensor", 0),
    ("arc/Greenhouse-monitoring/group9/Greenhouse-sensor", 0),
]

# --- APEX endpoints mapping ---
APEX_ENDPOINTS = {
    "soil_table": "/ords/g3_data/soil/v1/sensor",
    "water_table": "/ords/g3_data/irrigation/telemetry/",
    "Crop_table": "/ords/g3_data/crop-vision/crop_g5/",#changed to test group5 crop vision POST
    "Greenhouse_table9": "/ords/g3_data/iot/greenhouse/",
    "Greenhouse_table1" : "/ords/g3_data/greenhouse_group1/"
}

APEX_HOST = "oracleapex.com"

# --- Helper Functions ---
def parse_topic(topic: str):
    """Extract group_id and sensor_type from MQTT topic."""
    parts = topic.split("/")
    group_part = next((p for p in parts if p.startswith("group")), None)
    sensor_type = parts[-1] if parts else None

    group_id = None
    if group_part:
        try:
            group_id = int(group_part.replace("group", ""))
        except ValueError:
            pass
    return group_id, sensor_type

def get_table(sensor_type: str, group_id: int):
    """Return the table name for a given sensor type and group."""
    if sensor_type not in SENSOR_GROUP_MAP:
        return None
    for entry in SENSOR_GROUP_MAP[sensor_type]:
        if entry["group_id"] == group_id:
            return entry["table"]
    return None

def send_to_apex(endpoint_url: str, payload: dict):
    """Send payload as JSON to Oracle APEX endpoint."""
    try:
        conn = http.client.HTTPSConnection(APEX_HOST, timeout=5)
        body = json.dumps(payload)
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        conn.request("POST", endpoint_url, body=body, headers=headers)

        res = conn.getresponse()
        data = res.read().decode("utf-8")

        if res.status in [200, 201]:
            print(f"[APEX]  Data sent successfully: {payload}")
        else:
            print(f"[APEX]  Error {res.status}: {data}")

    except Exception as e:
        print(f"[APEX]  Failed to send data: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

# --- MQTT Callbacks ---
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[MQTT] Connected to broker")
        client.subscribe(MQTT_TOPICS)
        print("[MQTT] Subscribed to topics:", [t[0] for t in MQTT_TOPICS])
    else:
        print(f"[MQTT] Connection failed with code {rc}")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        print(f"[MQTT] Received from {msg.topic}: {payload}")

        group_id, sensor_type = parse_topic(msg.topic)
        table_name = get_table(sensor_type, group_id)
        if not table_name:
            print(f"[Routing] No table mapping for {sensor_type} group {group_id}")
            return

        endpoint_url = APEX_ENDPOINTS.get(table_name)
        if not endpoint_url:
            print(f"[Routing] No APEX endpoint configured for table {table_name}")
            return

        send_to_apex(endpoint_url, payload)

    except json.JSONDecodeError:
        print(f"[MQTT]  Invalid JSON from topic {msg.topic}")
    except Exception as e:
        print(f"[MQTT]  Error processing message: {e}")

# --- Main ---
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

print(f"[MQTT] Connecting to broker at {BROKER}:{PORT}...")
client.connect(BROKER, PORT, 60)
print("[MQTT] Listening for messages...")
client.loop_forever()
