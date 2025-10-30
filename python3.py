import paho.mqtt.client as mqtt

# === CONFIG ===
BROKER = "localhost"       # IP of your Raspberry Pi if running on Pi, or "192.168.x.x" if running elsewhere
PORT = 1883
TOPIC = "soilSensorGRP8/data"          # Subscribe to all topics under "esp32/"

# --- MQTT callbacks ---
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[MQTT] Connected successfully")
        client.subscribe(TOPIC, qos=1)
        print(f"[MQTT] Subscribed to topic: {TOPIC}")
    else:
        print(f"[MQTT] Connection failed with code {rc}")

def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8")
    print(f"[MQTT] Message received -> Topic: {msg.topic}, Payload: {payload}")

# --- Main ---
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

print(f"Connecting to MQTT broker at {BROKER}:{PORT}...")
client.connect(BROKER, PORT, 60)
client.loop_forever()
