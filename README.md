
### ARC Smart Agriculture Data Platform  
**Central Data Broker and API – Group 5**

---

### Overview  
The **ARC Smart Agriculture Data Platform** serves as the **central communication hub** and **data management layer** for the entire Smart Agriculture ecosystem.  

It connects multiple IoT subsystems — including greenhouse monitoring, soil sensing, and water management — through the **MQTT protocol** and provides structured APIs for storing, analyzing, and sharing agricultural data in real time.

---

###  System Architecture  
**Core Components:**
-   **ESP32 IoT Nodes** – Collect sensor data (soil, humidity, temperature, etc.) and publish via MQTT.  
-  **Mosquitto MQTT Broker** – Handles lightweight, fast message exchange between devices and backend services.  
- **Python Subscribers** – Listen to standardized MQTT topics and forward data to storage or analytics modules.  
- **Central Database / API** – Stores aggregated data and exposes it to dashboards or external systems.  

---

### MQTT Topic Standardization  
All device topics follow a consistent and hierarchical structure for clarity and scalability:  

```bash
arc/<project-section>/<group-id>/<sensor-type>
```

**Examples:**

```bash
- `arc/soil-monitoring/group8/soil-sensor`
- `arc/greenhouse-monitoring/group9/greenhouse-sensor`
- `arc/water-management/group10/water-sensor`
```

This makes it easy to subscribe selectively to specific groups or sensors using wildcard filters such as: 

arc/soil-monitoring/#
arc/+/group9/#

---

### Setup & Installation

### 1. Clone the Repository
```bash
git clone https://github.com/<your-org-or-username>/arc-smart-agric-data.git
cd arc-smart-agric-data
```

### 2. Create a Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate   # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Run the MQTT Subscriber

```bash
python mqtt_subscriber.py
Ensure your Mosquitto broker is running on port 1883 and accessible at the IP specified in the script.
```

### Testing Connectivity

You can verify broker communication using Mosquitto client tools:

# Subscribe to all topics

```bash
mosquitto_sub -t "arc/#"
```

# Publish a test message
```bash
mosquitto_pub -t "arc/soil-monitoring/group8/soil-sensor" -m "test message"
```

### Example Output

```bash
[MQTT] Connected successfully
[MQTT] Subscribed to topic: ['arc/soil-monitoring/group8/soil-sensor', 'arc/greenhouse-monitoring/group9/greenhouse-sensor']
[MQTT] Message received -> Topic: arc/soil-monitoring/group8/soil-sensor, Payload: {"moisture": 45.3, "temperature": 23.1}
```

### License

This project is for educational and research purposes under the ARC Smart Agriculture initiative.
© 2025 ARC Group 5. All rights reserved.
