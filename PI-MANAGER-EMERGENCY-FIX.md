# 🚨 Pi Manager Emergency Fix - Sofortlösung

## Problem
Das `install-pi-manager.sh` Script wurde nicht korrekt auf die SD-Karte kopiert und fehlt im `/boot` Verzeichnis.

## ⚡ Sofortlösung (Auf dem Pi ausführen)

### Option 1: One-Liner Fix (Empfohlen)
Führen Sie diesen Befehl **auf dem Pi** aus:

```bash
curl -s https://raw.githubusercontent.com/henningd/pi-manager/main/install-pi-manager.sh | sudo bash
```

### Option 2: Manueller Fix
Falls Option 1 nicht funktioniert:

```bash
# 1. Script direkt erstellen
cat > /home/pi/install-pi-manager.sh << 'EOF'
#!/bin/bash
# Pi Manager Auto-Install Script
echo "🥧 Starting Pi Manager installation..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script with sudo"
    exit 1
fi

# Get the actual user
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
apt install -y curl git build-essential

# Install Node.js 18.x
echo "📦 Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Clone Pi Manager
echo "📥 Cloning Pi Manager..."
cd $USER_HOME
rm -rf pi-manager
sudo -u $ACTUAL_USER git clone https://github.com/henningd/pi-manager.git
cd pi-manager

# Install dependencies
echo "📦 Installing dependencies..."
sudo -u $ACTUAL_USER npm install --production

# Set up systemd service
echo "⚙️ Setting up systemd service..."
cp scripts/pi-manager.service /etc/systemd/system/
sed -i "s|/opt/pi-manager|$USER_HOME/pi-manager|g" /etc/systemd/system/pi-manager.service
sed -i "s|User=pi|User=$ACTUAL_USER|g" /etc/systemd/system/pi-manager.service

# Enable and start service
systemctl daemon-reload
systemctl enable pi-manager
systemctl start pi-manager

# Configure system
timedatectl set-timezone Europe/Berlin
echo 'XKBLAYOUT="de"' >> /etc/default/keyboard

# Get IP address
PI_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Pi Manager installation completed!"
echo "🌐 Web Interface: http://$PI_IP:3000"
echo "🔐 Username: admin"
echo "🔐 Password: admin123"
echo ""
EOF

# 2. Script ausführbar machen
chmod +x /home/pi/install-pi-manager.sh

# 3. Installation starten
sudo /home/pi/install-pi-manager.sh
```

### Option 3: Emergency Fix Script verwenden
Falls Sie den Emergency Fix Script von Windows übertragen möchten:

```bash
# Von Windows aus (mit SCP)
scp scripts/emergency-fix-pi-manager.sh pi@<PI-IP>:/home/pi/

# Dann auf dem Pi
chmod +x /home/pi/emergency-fix-pi-manager.sh
./emergency-fix-pi-manager.sh
```

## 🔧 Troubleshooting

### Fehler: "git clone failed"
```bash
# Internet-Verbindung prüfen
ping -c 3 google.com

# DNS-Problem beheben
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
```

### Fehler: "Node.js installation failed"
```bash
# Alternative Node.js Installation
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Fehler: "Service failed to start"
```bash
# Service Status prüfen
sudo systemctl status pi-manager

# Logs anzeigen
sudo journalctl -u pi-manager -f

# Manual start
cd /home/pi/pi-manager
npm start
```

## 📋 Nach der Installation

1. **Web Interface öffnen:**
   ```
   http://<PI-IP-ADRESSE>:3000
   ```

2. **Standard-Anmeldedaten:**
   - Username: `admin`
   - Password: `admin123`

3. **IP-Adresse finden:**
   ```bash
   hostname -I
   ```

4. **Service-Management:**
   ```bash
   sudo systemctl status pi-manager    # Status prüfen
   sudo systemctl restart pi-manager   # Neustart
   sudo systemctl stop pi-manager      # Stoppen
   sudo systemctl start pi-manager     # Starten
   ```

## 🎯 Was passiert nach der Installation?

- ✅ Pi Manager läuft unter Port 3000
- ✅ Automatischer Start beim Booten
- ✅ SSH bleibt aktiviert
- ✅ Deutsche Tastatur konfiguriert
- ✅ Timezone auf Europe/Berlin gesetzt

## 🔄 Nächster Schritt: Master-Image erstellen

Sobald Pi Manager erfolgreich läuft, können wir ein Master-Image erstellen:

1. **SD-Karte optimieren** (temporäre Dateien entfernen)
2. **Image erstellen** (komplette SD-Karte sichern)
3. **Image komprimieren** (für einfache Verteilung)
4. **Flash-Scripts anpassen** (für Verwendung des Master-Images)

**Führen Sie zunächst Option 1 oder 2 aus, um Pi Manager zu installieren!**
