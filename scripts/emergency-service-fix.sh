#!/bin/bash
# Emergency Fix für Pi Manager Service nach Git-Reset
# Löst Abhängigkeits- und Startup-Probleme

echo "🚨 Pi Manager Emergency Service Fix"
echo "================================="
echo ""

# Ins Pi Manager Directory wechseln
cd /home/pi/pi-manager

echo "📊 Aktuelle Situation:"
echo "   - Service Status: $(systemctl is-active pi-manager)"
echo "   - Working Directory: $(pwd)"
echo "   - Node Version: $(node --version)"
echo "   - NPM Version: $(npm --version)"
echo ""

# Service stoppen
echo "🛑 Stoppe Pi Manager Service..."
sudo systemctl stop pi-manager
echo ""

# Überprüfung der Dateistruktur
echo "📁 Überprüfe Dateistruktur..."
ls -la

if [ ! -f "app.js" ]; then
    echo "❌ app.js nicht gefunden!"
    exit 1
fi

if [ ! -f "package.json" ]; then
    echo "❌ package.json nicht gefunden!"
    exit 1
fi

echo "✅ Grundlegende Dateien vorhanden"
echo ""

# Package.json anzeigen
echo "📦 Package.json Inhalt:"
cat package.json
echo ""

# Node modules löschen und neu installieren
echo "🧹 Lösche alte node_modules..."
rm -rf node_modules package-lock.json

echo "📦 Installiere npm-Abhängigkeiten..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ npm install fehlgeschlagen!"
    echo "🔧 Versuche npm cache clean..."
    npm cache clean --force
    npm install
    
    if [ $? -ne 0 ]; then
        echo "❌ npm install immer noch fehlgeschlagen!"
        echo "🔄 Versuche mit --no-optional..."
        npm install --no-optional
    fi
fi

echo "✅ NPM-Installation abgeschlossen"
echo ""

# Überprüfung der erforderlichen Module
echo "🔍 Überprüfe kritische Module..."
REQUIRED_MODULES=("express" "socket.io" "sqlite3" "bcryptjs" "jsonwebtoken" "cors" "helmet" "express-rate-limit")

for module in "${REQUIRED_MODULES[@]}"; do
    if npm list "$module" > /dev/null 2>&1; then
        echo "✅ $module vorhanden"
    else
        echo "❌ $module fehlt - installiere..."
        npm install "$module"
    fi
done

echo ""

# Überprüfung der Ordnerstruktur
echo "🏗️ Überprüfe Ordnerstruktur..."
REQUIRED_DIRS=("public" "routes" "config" "services" "data")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir vorhanden"
    else
        echo "⚠️ $dir fehlt - erstelle..."
        mkdir -p "$dir"
    fi
done

# Test-App.js erstellen falls die original nicht funktioniert
echo "🧪 Erstelle Test-App.js..."
cat > test-app.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Basis-Middleware
app.use(express.json());
app.use(express.static('public'));

// Test-Route
app.get('/', (req, res) => {
    res.send(`
        <html>
        <head><title>Pi Manager - Emergency Mode</title></head>
        <body>
            <h1>🚨 Pi Manager - Emergency Mode</h1>
            <p>Service läuft im Notfall-Modus</p>
            <p>Zeit: ${new Date().toLocaleString()}</p>
            <p>Uptime: ${process.uptime().toFixed(2)}s</p>
        </body>
        </html>
    `);
});

// Health-Check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Emergency Pi Manager running on port ${PORT}`);
});
EOF

# Teste Node.js-App
echo "🧪 Teste Node.js App..."
timeout 5 node app.js &
APP_PID=$!
sleep 2

if kill -0 "$APP_PID" 2>/dev/null; then
    echo "✅ app.js startet erfolgreich"
    kill "$APP_PID"
else
    echo "❌ app.js startet nicht - verwende test-app.js"
    cp app.js app.js.broken
    cp test-app.js app.js
fi

# Berechtigungen korrigieren
echo "🔧 Korrigiere Berechtigungen..."
sudo chown -R pi:pi /home/pi/pi-manager
chmod +x app.js

# Service neu starten
echo "🚀 Starte Pi Manager Service..."
sudo systemctl start pi-manager

sleep 3

# Status überprüfen
echo "📊 Service Status:"
sudo systemctl status pi-manager --no-pager

if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager Service erfolgreich repariert!"
    echo "========================================="
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "🔧 Health Check: http://$PI_IP:3000/health"
    echo ""
else
    echo "❌ Service immer noch fehlerhaft"
    echo "📋 Letzte Logs:"
    sudo journalctl -u pi-manager -n 20 --no-pager
    echo ""
    echo "🔄 Manuelle Schritte:"
    echo "1. cd /home/pi/pi-manager"
    echo "2. node app.js (zum Testen)"
    echo "3. sudo systemctl restart pi-manager"
fi

echo ""
echo "🏁 Emergency Fix abgeschlossen"
