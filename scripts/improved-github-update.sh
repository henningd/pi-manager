#!/bin/bash
# Verbessertes GitHub Update Script für Pi Manager
# Löst das Problem mit divergenten Branches

echo "🔄 Pi Manager GitHub Update (Verbessert)"
echo "========================================"
echo ""

# Ins Pi Manager Directory wechseln
cd /home/pi/pi-manager

# Aktueller Status
echo "📊 Aktueller Status:"
git status --porcelain
echo ""

# Backup erstellen
echo "💾 Erstelle Backup..."
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
cp -r /home/pi/pi-manager "$BACKUP_DIR"
echo "✅ Backup: $BACKUP_DIR"
echo ""

# Pi Manager stoppen
echo "🛑 Stoppe Pi Manager..."
sudo systemctl stop pi-manager
echo ""

# Git konfigurieren für automatisches Handling
echo "🔧 Konfiguriere Git für automatische Updates..."
git config pull.rebase false
git config pull.ff false
echo ""

# Fetch remote changes
echo "📥 Lade Remote-Änderungen..."
git fetch origin
echo ""

# Prüfe ob Branches divergent sind
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/main)

if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo "⚠️  Lokale und Remote-Branches sind unterschiedlich"
    echo "   Lokal:  $LOCAL_COMMIT"
    echo "   Remote: $REMOTE_COMMIT"
    echo ""
    
    # Merge-Basis finden
    MERGE_BASE=$(git merge-base HEAD origin/main)
    
    if [ "$MERGE_BASE" = "$LOCAL_COMMIT" ]; then
        echo "✅ Fast-Forward möglich"
        git pull origin main
    elif [ "$MERGE_BASE" = "$REMOTE_COMMIT" ]; then
        echo "✅ Lokale Änderungen sind aktueller"
        echo "   Pushe lokale Änderungen..."
        git push origin main
    else
        echo "🔀 Branches sind divergent - führe Smart-Merge durch"
        
        # Lokale Änderungen stashen
        git stash push -m "Auto-stash vor GitHub Update"
        
        # Hard reset auf remote
        git reset --hard origin/main
        
        # Prüfe ob Stash existiert
        if git stash list | grep -q "Auto-stash vor GitHub Update"; then
            echo "🔄 Versuche lokale Änderungen zu restaurieren..."
            git stash pop
            
            if [ $? -eq 0 ]; then
                echo "✅ Lokale Änderungen erfolgreich gemerged"
            else
                echo "⚠️  Merge-Konflikt - bitte manuell lösen"
                echo "   Verwende: git status"
                echo "   Dann: git add . && git commit -m 'Merge nach GitHub Update'"
            fi
        fi
    fi
else
    echo "✅ Repository ist bereits aktuell"
fi

echo ""
echo "📦 Prüfe npm-Abhängigkeiten..."
if [ -f "package.json" ]; then
    npm install
    echo "✅ npm install abgeschlossen"
else
    echo "⚠️  package.json nicht gefunden"
fi

echo ""
echo "🚀 Starte Pi Manager..."
sudo systemctl start pi-manager

# Warte auf Service-Start
sleep 3

if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager erfolgreich aktualisiert!"
    echo "====================================="
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "📊 Aktueller Git-Status:"
    git log --oneline -3
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden"
    echo "📋 Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
    echo ""
    echo "🔄 Wiederherstellung aus Backup:"
    echo "   sudo systemctl stop pi-manager"
    echo "   rm -rf /home/pi/pi-manager"
    echo "   cp -r $BACKUP_DIR /home/pi/pi-manager"
    echo "   sudo systemctl start pi-manager"
fi
