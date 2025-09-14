#!/bin/bash

# === VARIABEL CONFIGURABLE ===
MQTT_USER="iotuser"
MQTT_PASS="iotpassword"
MQTT_TOPIC="#"  # Topik yang diizinkan untuk user
DOMAIN="localhost"  # atau ganti dengan nama domain/server kamu

# === 1. Instalasi ===
sudo apt update
sudo apt install -y mosquitto mosquitto-clients openssl

# === 2. Buat folder certs dan generate sertifikat self-signed ===
CERT_DIR="/etc/mosquitto/certs"
sudo mkdir -p "$CERT_DIR"

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
 -keyout "$CERT_DIR/server.key" \
 -out "$CERT_DIR/server.crt" \
 -subj "/CN=$DOMAIN"

sudo cp "$CERT_DIR/server.crt" "$CERT_DIR/ca.crt"

# === 3. Buat file password dan ACL ===
PASSWD_FILE="/etc/mosquitto/passwd"
ACL_FILE="/etc/mosquitto/acl"

sudo mosquitto_passwd -b -c "$PASSWD_FILE" "$MQTT_USER" "$MQTT_PASS"

echo "user $MQTT_USER" | sudo tee "$ACL_FILE"
echo "topic readwrite $MQTT_TOPIC" | sudo tee -a "$ACL_FILE"

sudo chmod 600 "$PASSWD_FILE" "$ACL_FILE"

# === 4. Konfigurasi Mosquitto ===
CONF_FILE="/etc/mosquitto/conf.d/auth.conf"
sudo tee "$CONF_FILE" > /dev/null <<EOF
# MQTT tanpa TLS
listener 1883
protocol mqtt

# WebSocket tanpa TLS
listener 9001
protocol websockets

# MQTT dengan TLS
listener 8883
protocol mqtt
cafile $CERT_DIR/ca.crt
certfile $CERT_DIR/server.crt
keyfile $CERT_DIR/server.key

# WebSocket dengan TLS
listener 9443
protocol websockets
cafile $CERT_DIR/ca.crt
certfile $CERT_DIR/server.crt
keyfile $CERT_DIR/server.key

# Auth dan ACL
allow_anonymous false
password_file $PASSWD_FILE
acl_file $ACL_FILE
EOF

# === 5. Restart Mosquitto ===
sudo systemctl restart mosquitto
echo "✅ Mosquitto berhasil dikonfigurasi dengan aman!"

# === 6. Tes koneksi (opsional)
echo "Untuk menguji koneksi MQTT:"
echo "  mosquitto_sub -h localhost -t '#' -u $MQTT_USER -P $MQTT_PASS -p 1883"
echo "Untuk koneksi aman (TLS):"
echo "  mosquitto_sub -h localhost -t '#' -u $MQTT_USER -P $MQTT_PASS -p 8883 --cafile $CERT_DIR/ca.crt"
