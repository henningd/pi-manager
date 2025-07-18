#!/bin/bash
# Fix für divergente Git-Branches
# Lösung für das GitHub MCP Server Repository-Problem

echo "🔧 Git Divergent Branches Fix"
echo "============================="
echo ""

# Ins Pi Manager Directory wechseln
cd /home/pi/pi-manager

# Aktueller Status anzeigen
echo "📊 Aktueller Git-Status:"
git status
echo ""

echo "📋 Lokale Commits:"
git log --oneline -5
echo ""

echo "📋 Remote Commits:"
git log --oneline -5 origin/main
echo ""

# Backup erstellen
echo "💾 Erstelle Backup der lokalen Dateien..."
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
cp -r /home/pi/pi-manager "$BACKUP_DIR"
echo "✅ Backup erstellt: $BACKUP_DIR"
echo ""

# Verschiedene Lösungsoptionen anbieten
echo "🎯 Lösungsoptionen:"
echo "1. Force Push (überschreibt GitHub mit lokaler Version)"
echo "2. Hard Reset (überschreibt lokale Version mit GitHub)"
echo "3. Merge (versucht beide Versionen zu kombinieren)"
echo "4. Rebase (ordnet lokale Commits über GitHub-Commits)"
echo ""

read -p "Welche Option möchten Sie wählen? (1-4): " choice

case $choice in
    1)
        echo "🚀 Force Push - Lokale Version wird zu GitHub gepusht..."
        git push -f origin main
        if [ $? -eq 0 ]; then
            echo "✅ Force Push erfolgreich!"
        else
            echo "❌ Force Push fehlgeschlagen!"
        fi
        ;;
    2)
        echo "🔄 Hard Reset - GitHub Version wird lokal übernommen..."
        git fetch origin
        git reset --hard origin/main
        if [ $? -eq 0 ]; then
            echo "✅ Hard Reset erfolgreich!"
        else
            echo "❌ Hard Reset fehlgeschlagen!"
        fi
        ;;
    3)
        echo "🔀 Merge - Beide Versionen werden kombiniert..."
        git config pull.rebase false
        git pull origin main --allow-unrelated-histories
        if [ $? -eq 0 ]; then
            echo "✅ Merge erfolgreich!"
        else
            echo "❌ Merge fehlgeschlagen!"
        fi
        ;;
    4)
        echo "📐 Rebase - Lokale Commits werden über GitHub-Commits gesetzt..."
        git config pull.rebase true
        git pull origin main --allow-unrelated-histories
        if [ $? -eq 0 ]; then
            echo "✅ Rebase erfolgreich!"
        else
            echo "❌ Rebase fehlgeschlagen!"
        fi
        ;;
    *)
        echo "❌ Ungültige Option!"
        exit 1
        ;;
esac

echo ""
echo "📊 Neuer Git-Status:"
git status
echo ""

echo "📋 Aktuelle Commits:"
git log --oneline -5
echo ""

# Test ob git pull jetzt funktioniert
echo "🧪 Teste git pull..."
git pull origin main
if [ $? -eq 0 ]; then
    echo "✅ git pull funktioniert jetzt!"
else
    echo "⚠️  git pull immer noch problematisch"
fi

echo ""
echo "🎉 Git-Repository-Fix abgeschlossen!"
echo "💾 Backup verfügbar unter: $BACKUP_DIR"
echo ""
echo "📝 Nächste Schritte:"
echo "1. Prüfen Sie die Dateien im Repository"
echo "2. Testen Sie das Pi Manager System"
echo "3. Bei Problemen: Backup wiederherstellen"
