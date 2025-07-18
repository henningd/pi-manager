#!/bin/bash
# Pi Manager Service Diagnose und Reparatur Script

echo "🔍 Pi Manager Service Diagnose"
echo "============================="
echo ""

# Service Status prüfen
echo "📊 Service Status:"
systemctl status pi-manager --no-pager
echo ""

# Logs anzeigen
echo "📝 Aktuelle Logs:"
journalctl -u pi-manager -n 20 --no-pager
echo ""

# Prüfe ob Port 3000 bereits belegt ist
echo "🔍 Port 3000 Überprüfung:"
if netstat -tlnp | grep -q ":3000 "; then
    echo "⚠️  Port 3000 ist bereits belegt:"
    netstat -tlnp | grep ":3000 "
    echo "🔧 Versuche Prozess zu beenden..."
    sudo fuser -k 3000/tcp
    sleep 2
else
    echo "✅ Port 3000 ist frei"
fi
echo ""

# Prüfe Pi Manager Directory
echo "📁 Pi Manager Directory:"
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)
PI_MANAGER_DIR="$USER_HOME/pi-manager"

if [ -d "$PI_MANAGER_DIR" ]; then
    echo "✅ Pi Manager Directory existiert: $PI_MANAGER_DIR"
    echo "📂 Inhalt:"
    ls -la "$PI_MANAGER_DIR"
    echo ""
    
    # Prüfe package.json
    if [ -f "$PI_MANAGER_DIR/package.json" ]; then
        echo "✅ package.json gefunden"
        echo "📋 Main Script:"
        grep -A 1 -B 1 '"main"' "$PI_MANAGER_DIR/package.json"
        echo ""
    else
        echo "❌ package.json nicht gefunden"
    fi
    
    # Prüfe app.js
    if [ -f "$PI_MANAGER_DIR/app.js" ]; then
        echo "✅ app.js gefunden"
    else
        echo "❌ app.js nicht gefunden"
        echo "📝 Verfügbare .js Dateien:"
        find "$PI_MANAGER_DIR" -name "*.js" -type f
    fi
else
    echo "❌ Pi Manager Directory nicht gefunden: $PI_MANAGER_DIR"
fi
echo ""

# Prüfe Service-Datei
echo "⚙️ Service-Datei Überprüfung:"
SERVICE_FILE="/etc/systemd/system/pi-manager.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "✅ Service-Datei gefunden"
    echo "📄 Inhalt:"
    cat "$SERVICE_FILE"
else
    echo "❌ Service-Datei nicht gefunden"
fi
echo ""

# Prüfe Node.js
echo "🔧 Node.js Installation:"
if command -v node &> /dev/null; then
    echo "✅ Node.js Version: $(node --version)"
    echo "✅ npm Version: $(npm --version)"
else
    echo "❌ Node.js nicht gefunden"
fi
echo ""

# Automatische Reparatur
echo "🔧 Automatische Reparatur startet..."
echo "=================================="

# 1. Service-Datei reparieren
echo "🔧 Repariere Service-Datei..."
cat > /etc/systemd/system/pi-manager.service << EOF
[Unit]
Description=Pi Manager - Raspberry Pi Management Web Interface
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=$ACTUAL_USER
WorkingDirectory=$PI_MANAGER_DIR
ExecStart=/usr/bin/node app.js
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service-Datei aktualisiert"

# 2. Permissions korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
chown -R $ACTUAL_USER:$ACTUAL_USER "$PI_MANAGER_DIR"
chmod -R 755 "$PI_MANAGER_DIR"

# 3. Prüfe ob app.js existiert, falls nicht erstelle einen einfachen
if [ ! -f "$PI_MANAGER_DIR/app.js" ]; then
    echo "🔧 Erstelle minimale app.js..."
    cat > "$PI_MANAGER_DIR/app.js" << 'EOF'
const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// Basic route
app.get('/', (req, res) => {
    res.send(`
        <h1>🥧 Pi Manager</h1>
        <p>Pi Manager ist erfolgreich installiert!</p>
        <p>IP: ${req.ip}</p>
        <p>Zeit: ${new Date().toLocaleString('de-DE')}</p>
        <hr>
        <p>Login: admin / admin123</p>
    `);
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`🥧 Pi Manager läuft auf Port ${port}`);
    console.log(`🌐 Zugriff über: http://localhost:${port}`);
});
EOF
    chown $ACTUAL_USER:$ACTUAL_USER "$PI_MANAGER_DIR/app.js"
    echo "✅ Minimale app.js erstellt"
fi

# 4. Systemd neu laden
echo "🔧 Systemd neu laden..."
systemctl daemon-reload

# 5. Service aktivieren und starten
echo "🔧 Service aktivieren und starten..."
systemctl enable pi-manager
systemctl start pi-manager

# 6. Warten und Status prüfen
echo "⏳ Warte 5 Sekunden..."
sleep 5

echo ""
echo "🎯 Finaler Status:"
echo "=================="

if systemctl is-active --quiet pi-manager; then
    echo "✅ Pi Manager Service läuft erfolgreich!"
    
    # IP-Adresse ermitteln
    PI_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "🌐 Zugriff auf Pi Manager:"
    echo "   Web Interface: http://$PI_IP:3000"
    echo "   Local: http://localhost:3000"
    echo ""
    echo "🔐 Standard-Anmeldedaten:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "🔧 Service Management:"
    echo "   Status: sudo systemctl status pi-manager"
    echo "   Logs:   sudo journalctl -u pi-manager -f"
    echo "   Restart: sudo systemctl restart pi-manager"
    echo ""
    
    # Test HTTP Request
    echo "🧪 Connection Test:"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
        echo "✅ HTTP-Verbindung erfolgreich"
    else
        echo "⚠️  HTTP-Verbindung fehlgeschlagen"
    fi
    
else
    echo "❌ Pi Manager Service konnte nicht gestartet werden"
    echo ""
    echo "🔍 Detaillierte Logs:"
    journalctl -u pi-manager -n 50 --no-pager
    echo ""
    echo "🔧 Manuelle Fehlerbehebung:"
    echo "   1. Logs prüfen: sudo journalctl -u pi-manager -f"
    echo "   2. Manual test: cd /home/pi/pi-manager && node app.js"
    echo "   3. Port prüfen: netstat -tlnp | grep :3000"
    echo "   4. Service restart: sudo systemctl restart pi-manager"
fi

echo ""
echo "🎉 Diagnose abgeschlossen!"
