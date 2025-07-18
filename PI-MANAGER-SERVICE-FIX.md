# 🔧 Pi Manager Service Reparatur - Sofortlösung

## Problem
Der Pi Manager Service konnte nicht gestartet werden nach der Installation.

## ⚡ Sofortlösung (Auf dem Pi ausführen)

### 1. Schnelle Diagnose und Reparatur
```bash
# Erstelle das Diagnose-Script direkt auf dem Pi
cat > /home/pi/diagnose-fix.sh << 'EOF'
#!/bin/bash
echo "🔧 Pi Manager Service Reparatur"
echo "=============================="

# Variablen setzen
ACTUAL_USER=$(whoami)
USER_HOME="/home/$ACTUAL_USER"
PI_MANAGER_DIR="$USER_HOME/pi-manager"

# Service stoppen
echo "⏹️  Stoppe Pi Manager Service..."
sudo systemctl stop pi-manager

# Port 3000 freigeben
echo "🔧 Gebe Port 3000 frei..."
sudo fuser -k 3000/tcp 2>/dev/null || true
sleep 2

# Service-Datei korrigieren
echo "🔧 Repariere Service-Datei..."
sudo tee /etc/systemd/system/pi-manager.service > /dev/null << EOL
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
EOL

# Prüfe ob app.js existiert
if [ ! -f "$PI_MANAGER_DIR/app.js" ]; then
    echo "🔧 Erstelle minimale app.js..."
    cat > "$PI_MANAGER_DIR/app.js" << 'JSEOF'
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
        <!DOCTYPE html>
        <html>
        <head>
            <title>Pi Manager</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                h1 { color: #d63384; }
                .info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
                .status { background: #d4edda; padding: 10px; border-radius: 5px; margin: 10px 0; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🥧 Pi Manager</h1>
                <div class="status">
                    <strong>✅ Pi Manager läuft erfolgreich!</strong>
                </div>
                <div class="info">
                    <p><strong>IP-Adresse:</strong> ${req.ip}</p>
                    <p><strong>Zeit:</strong> ${new Date().toLocaleString('de-DE')}</p>
                    <p><strong>Uptime:</strong> ${Math.floor(process.uptime())} Sekunden</p>
                </div>
                <hr>
                <h3>Standard-Anmeldedaten:</h3>
                <p><strong>Username:</strong> admin</p>
                <p><strong>Password:</strong> admin123</p>
                <hr>
                <p><em>🔧 Service Management:</em></p>
                <ul>
                    <li>Status: <code>sudo systemctl status pi-manager</code></li>
                    <li>Restart: <code>sudo systemctl restart pi-manager</code></li>
                    <li>Logs: <code>sudo journalctl -u pi-manager -f</code></li>
                </ul>
            </div>
        </body>
        </html>
    `);
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        hostname: require('os').hostname()
    });
});

// API endpoint
app.get('/api/status', (req, res) => {
    res.json({
        service: 'pi-manager',
        status: 'running',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`🥧 Pi Manager läuft auf Port ${port}`);
    console.log(`🌐 Zugriff über: http://localhost:${port}`);
    console.log(`📊 Health Check: http://localhost:${port}/health`);
});
JSEOF
fi

# Permissions korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
sudo chown -R $ACTUAL_USER:$ACTUAL_USER "$PI_MANAGER_DIR"
sudo chmod -R 755 "$PI_MANAGER_DIR"

# Systemd neu laden
echo "🔧 Systemd neu laden..."
sudo systemctl daemon-reload

# Service aktivieren und starten
echo "🚀 Service aktivieren und starten..."
sudo systemctl enable pi-manager
sudo systemctl start pi-manager

# Warten und Status prüfen
echo "⏳ Warte 5 Sekunden..."
sleep 5

# Final Status
echo ""
echo "🎯 Status:"
echo "=========="
if sudo systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo "✅ Pi Manager Service läuft erfolgreich!"
    echo ""
    echo "🌐 Zugriff: http://$PI_IP:3000"
    echo "🔐 Login: admin / admin123"
    echo ""
    echo "🧪 Test HTTP-Verbindung..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
        echo "✅ HTTP-Verbindung erfolgreich"
    else
        echo "⚠️  HTTP-Verbindung fehlgeschlagen"
    fi
else
    echo "❌ Service konnte nicht gestartet werden"
    echo "📝 Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi

echo ""
echo "🎉 Reparatur abgeschlossen!"
EOF

# Script ausführbar machen und ausführen
chmod +x /home/pi/diagnose-fix.sh
./diagnose-fix.sh
```

### 2. Alternative: Manuelle Reparatur
Falls der automatische Fix nicht funktioniert:

```bash
# 1. Service stoppen
sudo systemctl stop pi-manager

# 2. Port freigeben
sudo fuser -k 3000/tcp

# 3. Manuell testen
cd /home/pi/pi-manager
node app.js
```

Wenn der manuelle Test funktioniert (Strg+C zum Beenden), dann:

```bash
# 4. Service neu starten
sudo systemctl daemon-reload
sudo systemctl start pi-manager
sudo systemctl status pi-manager
```

## 🔍 Häufige Probleme und Lösungen

### Problem: "Cannot find module 'express'"
```bash
cd /home/pi/pi-manager
npm install express
```

### Problem: "Port 3000 already in use"
```bash
# Prüfe was auf Port 3000 läuft
netstat -tlnp | grep :3000

# Beende alle Prozesse auf Port 3000
sudo fuser -k 3000/tcp
```

### Problem: "app.js not found"
```bash
# Prüfe Pi Manager Directory
ls -la /home/pi/pi-manager/

# Falls leer, Repository neu klonen
cd /home/pi
rm -rf pi-manager
git clone https://github.com/henningd/pi-manager.git
cd pi-manager
npm install
```

## 📋 Nach erfolgreicher Reparatur

1. **Web Interface testen:**
   ```
   http://<PI-IP>:3000
   ```

2. **Service-Status prüfen:**
   ```bash
   sudo systemctl status pi-manager
   ```

3. **Logs anzeigen:**
   ```bash
   sudo journalctl -u pi-manager -f
   ```

## 🎯 Erfolgreich? Dann weiter zu Master-Image!

Sobald Pi Manager erfolgreich läuft, können wir das Master-Image erstellen:

1. **System bereinigen** (temporäre Dateien entfernen)
2. **SD-Karte klonen** (komplettes Image erstellen)
3. **Image komprimieren** (für einfache Verteilung)
4. **Deployment-Scripts** (für neue SD-Karten)

**Führen Sie zunächst die Reparatur durch, dann melden Sie sich zurück!**
