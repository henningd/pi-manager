#!/bin/bash
# Force Update für das neue Pi Manager Design
# Stellt sicher, dass die neue index.html und CSS geladen werden

echo "🎨 Pi Manager Design Update"
echo "============================"
echo ""

# Prüfe ob Pi Manager läuft
if systemctl is-active --quiet pi-manager; then
    echo "🔄 Stoppe Pi Manager..."
    sudo systemctl stop pi-manager
    sleep 2
fi

# Wechsle ins Pi Manager Directory
cd /home/pi/pi-manager

# Backup erstellen
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
echo "💾 Erstelle Backup: $BACKUP_DIR"
cp -r /home/pi/pi-manager "$BACKUP_DIR"

# Git Status prüfen
echo "📊 Git Status vor Update:"
git status --porcelain

# Lokale Änderungen stashen (falls vorhanden)
if [[ -n $(git status --porcelain) ]]; then
    echo "💾 Stashe lokale Änderungen..."
    git stash push -m "Backup vor Design Update"
fi

# Fetch und Pull
echo "📥 Lade neueste Version von GitHub..."
git fetch origin
git reset --hard origin/master

# Prüfe ob neue Dateien vorhanden sind
if [[ -f "public/index.html" ]] && [[ -f "public/css/style.css" ]]; then
    echo "✅ Neue Design-Dateien gefunden:"
    echo "   - public/index.html"
    echo "   - public/css/style.css"
    echo "   - public/js/app.js"
else
    echo "❌ Design-Dateien nicht gefunden!"
    echo "   Repository könnte nicht aktuell sein"
fi

# Cache leeren
echo "🧹 Leere Browser-Cache..."
rm -rf /home/pi/.cache/chromium* 2>/dev/null || true

# Nodejs Cache leeren
echo "🧹 Leere Node.js Cache..."
npm cache clean --force 2>/dev/null || true

# Rechte korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
sudo chown -R pi:pi /home/pi/pi-manager
chmod -R 755 /home/pi/pi-manager

# Service neu starten
echo "🚀 Starte Pi Manager neu..."
sudo systemctl start pi-manager

# Warte auf Service-Start
echo "⏳ Warte auf Service-Start..."
sleep 5

# Status prüfen
if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager erfolgreich aktualisiert!"
    echo "======================================"
    echo ""
    echo "✨ Neues Design Features:"
    echo "   - Modernes, professionelles Dashboard"
    echo "   - Interaktive System-Überwachung"
    echo "   - Echtzeit-Updates"
    echo "   - Responsive Design"
    echo "   - GitHub Integration"
    echo "   - System-Logs"
    echo "   - Action-Buttons"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💡 Tipp: Drücke Strg+F5 für Hard-Refresh"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "🔍 Teste das neue Design:"
    echo "   1. Öffne http://$PI_IP:3000"
    echo "   2. Drücke Strg+F5 für Hard-Refresh"
    echo "   3. Prüfe die System-Metriken"
    echo "   4. Teste die Action-Buttons"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
    echo ""
    echo "🔄 Rollback durchführen:"
    echo "   sudo systemctl stop pi-manager"
    echo "   rm -rf /home/pi/pi-manager"
    echo "   cp -r $BACKUP_DIR /home/pi/pi-manager"
    echo "   sudo systemctl start pi-manager"
fi

echo ""
echo "📝 Nächste Schritte:"
echo "   1. Browser-Cache leeren (Strg+F5)"
echo "   2. Inkognito-Modus testen"
echo "   3. Mobilgeräte testen"
echo "   4. Funktionalität prüfen"
