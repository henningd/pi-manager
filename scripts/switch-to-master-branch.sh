#!/bin/bash
# Wechselt den Pi Manager vom main Branch zum master Branch
# Löst das Problem mit dem fehlenden neuen Design

echo "🔄 Pi Manager Branch Switch: main → master"
echo "=========================================="
echo ""

# Prüfe aktuellen Branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📊 Aktueller Branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "master" ]; then
    echo "✅ Bereits auf master Branch!"
    echo "🔄 Führe trotzdem Update durch..."
else
    echo "🔄 Wechsle von $CURRENT_BRANCH zu master..."
fi

# Prüfe ob Pi Manager läuft
if systemctl is-active --quiet pi-manager; then
    echo "🛑 Stoppe Pi Manager..."
    sudo systemctl stop pi-manager
    sleep 2
fi

# Wechsle ins Pi Manager Directory
cd /home/pi/pi-manager

# Backup erstellen
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
echo "💾 Erstelle Backup: $BACKUP_DIR"
cp -r /home/pi/pi-manager "$BACKUP_DIR"

# Lokale Änderungen stashen
echo "💾 Sichere lokale Änderungen..."
git stash push -m "Backup vor Branch Switch"

# Fetch alle Remote-Branches
echo "📥 Lade Remote-Branches..."
git fetch origin

# Wechsle zum master Branch
echo "🔄 Wechsle zu master Branch..."
git checkout master

# Pull die neuesten Änderungen
echo "📥 Lade neueste Änderungen vom master Branch..."
git pull origin master

# Prüfe ob neue Design-Dateien vorhanden sind
echo "🔍 Prüfe Design-Dateien..."
if [[ -f "public/index.html" ]] && [[ -f "public/css/style.css" ]]; then
    echo "✅ Neue Design-Dateien gefunden!"
    echo "   📄 public/index.html"
    echo "   🎨 public/css/style.css"
    echo "   ⚙️ public/js/app.js"
    
    # Zeige Dateigröße für Verifikation
    echo ""
    echo "📊 Datei-Informationen:"
    ls -lh public/index.html
    ls -lh public/css/style.css
    ls -lh public/js/app.js 2>/dev/null || echo "   ⚠️ public/js/app.js nicht vorhanden"
else
    echo "❌ Design-Dateien nicht gefunden!"
    echo "   Repository ist möglicherweise nicht vollständig"
fi

# npm install (falls package.json geändert wurde)
if [[ -f "package.json" ]]; then
    echo "📦 Installiere npm-Abhängigkeiten..."
    npm install
fi

# Cache leeren
echo "🧹 Leere Cache..."
rm -rf /home/pi/.cache/chromium* 2>/dev/null || true
npm cache clean --force 2>/dev/null || true

# Rechte korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
sudo chown -R pi:pi /home/pi/pi-manager
chmod -R 755 /home/pi/pi-manager

# Pi Manager starten
echo "🚀 Starte Pi Manager..."
sudo systemctl start pi-manager

# Warte auf Service-Start
echo "⏳ Warte auf Service-Start..."
sleep 5

# Status prüfen
if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager erfolgreich auf master Branch aktualisiert!"
    echo "======================================================"
    echo ""
    echo "✅ Branch Switch erfolgreich:"
    echo "   Vorher: $CURRENT_BRANCH"
    echo "   Jetzt:  $(git branch --show-current)"
    echo ""
    echo "🎨 Neues Design sollte jetzt sichtbar sein:"
    echo "   - Professionelles Dashboard"
    echo "   - System-Monitoring"
    echo "   - Interaktive Elemente"
    echo "   - Moderne UI"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💡 Wichtig: Drücke Strg+F5 für Hard-Refresh!"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "📊 Git-Status:"
    git log --oneline -3
    echo ""
    echo "🔍 Teste das neue Design:"
    echo "   1. Öffne http://$PI_IP:3000"
    echo "   2. Drücke Strg+F5 (Hard-Refresh)"
    echo "   3. Teste Inkognito-Modus"
    echo "   4. Prüfe Mobile-Ansicht"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Fehler-Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
    echo ""
    echo "🔄 Rollback durchführen:"
    echo "   sudo systemctl stop pi-manager"
    echo "   rm -rf /home/pi/pi-manager"
    echo "   cp -r $BACKUP_DIR /home/pi/pi-manager"
    echo "   sudo systemctl start pi-manager"
fi

echo ""
echo "📝 Zusätzliche Tipps:"
echo "   - Browser-Cache vollständig leeren"
echo "   - Verschiedene Browser testen"
echo "   - Prüfe Developer Tools (F12)"
echo "   - Teste von anderen Geräten"
