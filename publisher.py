import json
import base64
import http.client
from urllib.parse import urlparse
from paho.mqtt import client as mqtt

# ------------------- CONFIGURATION -------------------

BROKER = "localhost"
PORT = 1883

# Basic Authentication for APEX
API_USER = "----------"
API_PASSWORD = "------------"

# Encode Basic Auth credentials once
auth_token = base64.b64encode(f"{API_USER}:{API_PASSWORD}".encode()).decode()

# Endpoints for each sensor type
ENDPOINTS = {
    "soil-sensor": "https://oracleapex.com/ords/g3_data/soil/v1/sensor",
    "Greenhouse-sensor": "https://oracleapex.com/ords/g3_data/greenhouse/",
    "Crop-sensor": "https://oracleapex.com/ords/g3_data/soil_vision/",
    "water-sensor": "https://oracleapex.com/ords/g3_data/irrigation/"
}

# MQTT Topics
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

# ------------------- HELPER FUNCTIONS -------------------

def map_payload(sensor_type, raw_payload):
    """
    Transforms incoming payload fields into the structure expected by APEX.
    """
    if sensor_type == "soil-sensor":
        return {
            "MOISTURE": raw_payload.get("moisture"),
            "TEMPERATURE": raw_payload.get("temperature"),
            "EC": raw_payload.get("ec"),
            "PH": raw_payload.get("ph"),
            "NITROGEN": raw_payload.get("nitrogen"),
            "PHOSPHORUS": raw_payload.get("phosphorus"),
            "POTASSIUM": raw_payload.get("potassium"),
            "VALID": raw_payload.get("valid", "Y")
        }

    elif sensor_type == "Greenhouse-sensor":
        return {
            "SENSOR_ID": raw_payload.get("sensor_id"),
            "TEMPERATURE": raw_payload.get("temperature"),
            "HUMIDITY": raw_payload.get("humidity"),
            "CO2": raw_payload.get("co2"),
            "PRESSURE": raw_payload.get("pressure"),
            "LIGHT_INTENSITY": raw_payload.get("light_intensity")
        }

    elif sensor_type == "Crop-sensor":
        return {
            "IMAGE_ID": raw_payload.get("image_id"),
            "PLANT_ID": raw_payload.get("plant_id"),
            "HEALTH_STATUS": raw_payload.get("health_status"),
            "DISEASE_DETECTED": raw_payload.get("disease_detected"),
            "PEST_DETECTED": raw_payload.get("pest_detected"),
            "GROWTH_STAGE": raw_payload.get("growth_stage"),
            "CONFIDENCE_SCORE": raw_payload.get("confidence_score")
        }

    elif sensor_type == "water-sensor":
        return {
            "SENSOR_ID": raw_payload.get("sensor_id"),
            "FLOW_RATE": raw_payload.get("flow_rate"),
            "VALVE_STATUS": raw_payload.get("valve_status"),
            "WATER_USAGE": raw_payload.get("water_usage"),
            "PUMP_STATUS": raw_payload.get("pump_status")
        }

    return raw_payload


def send_to_apex(sensor_type, payload):
    """
    Sends the mapped payload to the corresponding APEX REST endpoint with Basic Auth.
    """
    if sensor_type not in ENDPOINTS:
        print(f"[APEX] Unknown sensor type: {sensor_type}")
        return

    url = urlparse(ENDPOINTS[sensor_type])
    conn = http.client.HTTPSConnection(url.hostname)

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Basic {auth_token}",
        "Accept": "application/json"
    }

    json_payload = json.dumps(payload)
    print(f"\n[APEX] Posting to {ENDPOINTS[sensor_type]} with payload:\n{json_payload}")

    conn.request("POST", url.path, body=json_payload, headers=headers)
    response = conn.getresponse()
    response_data = response.read().decode()

    print(f"[APEX] Status: {response.status}")
    print(f"[APEX] Response: {response_data}")
    conn.close()

# ------------------- MQTT CALLBACKS -------------------

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[MQTT] Connected successfully.")
        client.subscribe(MQTT_TOPICS)
        print("[MQTT] Subscribed to:")
        for t, _ in MQTT_TOPICS:
            print(" -", t)
    else:
        print(f"[MQTT] Connection failed with code {rc}")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode("utf-8"))
        topic_parts = msg.topic.split("/")
        sensor_type = topic_parts[-1]  # e.g. soil-sensor, Crop-sensor, etc.

        print(f"\n[MQTT] Message received from {msg.topic}")
        print("[MQTT] Raw Payload:", payload)

        mapped_payload = map_payload(sensor_type, payload)
        send_to_apex(sensor_type, mapped_payload)

    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON in message: {e}")
    except Exception as ex:
        print(f"[ERROR] on_message failed: {ex}")

# ------------------- MAIN -------------------

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

print(f"[SYSTEM] Connecting to MQTT broker at {BROKER}:{PORT}...")
client.connect(BROKER, PORT, 60)
print("[SYSTEM] Listening for messages...")
client.loop_forever()
