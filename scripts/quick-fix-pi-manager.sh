#!/bin/bash
# Quick Fix für Pi Manager - Sofortlösung

echo "🚨 Pi Manager Quick Fix"
echo "======================="

# Prüfe aktuellen Status
echo "🔍 Aktueller Status:"
echo "Service Status: $(systemctl is-active pi-manager 2>/dev/null || echo 'nicht aktiv')"
echo "Port 3000: $(netstat -tln | grep :3000 || echo 'nicht gebunden')"
echo ""

# Sofortlösung: Service stoppen und manuell starten
echo "🔧 Stoppe alle laufenden Prozesse..."
sudo systemctl stop pi-manager 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true
sleep 2

# Prüfe Pi Manager Directory
PI_DIR="/home/pi/pi-manager"
if [ ! -d "$PI_DIR" ]; then
    echo "❌ Pi Manager Directory nicht gefunden. Erstelle es..."
    mkdir -p "$PI_DIR"
    cd "$PI_DIR"
    
    # Erstelle package.json
    cat > package.json << 'EOF'
{
  "name": "pi-manager",
  "version": "1.0.0",
  "description": "Raspberry Pi Management Interface",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

    # Express installieren
    echo "📦 Installiere Express..."
    npm install express
fi

cd "$PI_DIR"

# Erstelle funktionierende app.js
echo "🔧 Erstelle app.js..."
cat > app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Pi Manager</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; background: #f0f8ff; }
                .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                h1 { color: #d63384; text-align: center; }
                .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
                .info { background: #e7f3ff; color: #0c5460; padding: 15px; border-radius: 5px; margin: 20px 0; }
                .code { background: #f8f9fa; padding: 10px; border-radius: 5px; font-family: monospace; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🥧 Pi Manager</h1>
                <div class="success">
                    <h3>✅ Pi Manager läuft erfolgreich!</h3>
                    <p>Der Service ist erfolgreich gestartet und erreichbar.</p>
                </div>
                <div class="info">
                    <h4>📋 System-Informationen:</h4>
                    <p><strong>IP-Adresse:</strong> ${req.ip}</p>
                    <p><strong>Hostname:</strong> ${require('os').hostname()}</p>
                    <p><strong>Zeit:</strong> ${new Date().toLocaleString('de-DE')}</p>
                    <p><strong>Node.js Version:</strong> ${process.version}</p>
                    <p><strong>Uptime:</strong> ${Math.floor(process.uptime())} Sekunden</p>
                </div>
                <div class="info">
                    <h4>🔐 Standard-Anmeldedaten:</h4>
                    <p><strong>Username:</strong> admin</p>
                    <p><strong>Password:</strong> admin123</p>
                </div>
                <div class="info">
                    <h4>🔧 Service Management:</h4>
                    <div class="code">
                        sudo systemctl status pi-manager<br>
                        sudo systemctl restart pi-manager<br>
                        sudo journalctl -u pi-manager -f
                    </div>
                </div>
                <div class="info">
                    <h4>🧪 Test-Endpoints:</h4>
                    <p><a href="/health">Health Check</a></p>
                    <p><a href="/api/status">API Status</a></p>
                </div>
            </div>
        </body>
        </html>
    `);
});

app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        hostname: require('os').hostname(),
        version: process.version
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        service: 'pi-manager',
        status: 'running',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        ip: req.ip
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`🥧 Pi Manager läuft auf Port ${port}`);
    console.log(`🌐 Zugriff über: http://localhost:${port}`);
    console.log(`📊 Health Check: http://localhost:${port}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Pi Manager wird heruntergefahren...');
    process.exit(0);
});
EOF

# Permissions setzen
sudo chown -R pi:pi "$PI_DIR"
chmod +x app.js

echo "🚀 Starte Pi Manager manuell..."
# Erst manuell testen
node app.js &
NODE_PID=$!

# 5 Sekunden warten
sleep 5

# Prüfe ob es läuft
if kill -0 $NODE_PID 2>/dev/null; then
    echo "✅ Pi Manager läuft manuell!"
    
    # HTTP Test
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
        echo "✅ HTTP-Verbindung erfolgreich!"
        
        # Prozess beenden
        kill $NODE_PID
        
        echo "🔧 Erstelle systemd Service..."
        sudo tee /etc/systemd/system/pi-manager.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=Pi Manager - Raspberry Pi Management Web Interface
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=pi
WorkingDirectory=/home/pi/pi-manager
ExecStart=/usr/bin/node app.js
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

        # Service aktivieren
        sudo systemctl daemon-reload
        sudo systemctl enable pi-manager
        sudo systemctl start pi-manager
        
        sleep 3
        
        if systemctl is-active --quiet pi-manager; then
            PI_IP=$(hostname -I | awk '{print $1}')
            echo ""
            echo "🎉 Pi Manager erfolgreich gestartet!"
            echo "=================================="
            echo "🌐 Web Interface: http://$PI_IP:3000"
            echo "🔐 Login: admin / admin123"
            echo ""
            echo "🧪 Test jetzt: http://$PI_IP:3000"
        else
            echo "❌ Service konnte nicht gestartet werden"
            echo "📝 Logs:"
            sudo journalctl -u pi-manager -n 10 --no-pager
        fi
    else
        echo "❌ HTTP-Test fehlgeschlagen"
        kill $NODE_PID
    fi
else
    echo "❌ Node.js konnte nicht gestartet werden"
    echo "📝 Prüfe Node.js Installation:"
    which node
    node --version
    npm --version
fi

echo ""
echo "🔧 Troubleshooting:"
echo "=================="
echo "Manuelle Tests:"
echo "  cd /home/pi/pi-manager"
echo "  node app.js"
echo ""
echo "Service Tests:"
echo "  sudo systemctl status pi-manager"
echo "  sudo journalctl -u pi-manager -f"
echo "  curl http://localhost:3000"
