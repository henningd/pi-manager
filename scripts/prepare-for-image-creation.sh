#!/bin/bash
# Vorbereitung der SD-Karte für Master-Image Erstellung
# Dieses Script optimiert das System für die Image-Erstellung

echo "🥧 Pi Manager - Image-Vorbereitung"
echo "=================================="
echo ""

# Prüfe ob Pi Manager läuft
if systemctl is-active --quiet pi-manager; then
    echo "✅ Pi Manager Service läuft - bereit für Image-Erstellung"
else
    echo "❌ Pi Manager Service läuft nicht - bitte zuerst reparieren"
    exit 1
fi

echo "📋 System-Optimierung für Image-Erstellung..."
echo ""

# 1. Temporäre Dateien löschen
echo "🧹 Lösche temporäre Dateien..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo rm -rf /home/pi/.cache/*
sudo rm -rf /home/pi/.npm/_cacache/*
sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/log/*.log
sudo rm -rf /var/log/*/*.log
sudo rm -rf /root/.cache/*
sudo rm -rf /root/.npm/_cacache/* 2>/dev/null || true

echo "✅ Temporäre Dateien gelöscht"

# 2. SSH Host Keys löschen (werden beim ersten Boot neu generiert)
echo "🔐 Entferne SSH Host Keys (werden beim ersten Boot neu generiert)..."
sudo rm -f /etc/ssh/ssh_host_*
echo "✅ SSH Host Keys entfernt"

# 3. Bash History löschen
echo "📝 Lösche Bash History..."
rm -f /home/pi/.bash_history
sudo rm -f /root/.bash_history
echo "✅ Bash History gelöscht"

# 4. Machine ID löschen (wird beim ersten Boot neu generiert)
echo "🆔 Entferne Machine ID..."
sudo truncate -s 0 /etc/machine-id
sudo truncate -s 0 /var/lib/dbus/machine-id
echo "✅ Machine ID entfernt"

# 5. DHCP Leases löschen
echo "🌐 Lösche DHCP Leases..."
sudo rm -f /var/lib/dhcp/*
sudo rm -f /var/lib/dhcpcd5/*
echo "✅ DHCP Leases gelöscht"

# 6. Lokale Netzwerk-Konfiguration löschen
echo "🔧 Entferne lokale Netzwerk-Konfiguration..."
sudo rm -f /etc/wpa_supplicant/wpa_supplicant.conf
echo "✅ WLAN-Konfiguration entfernt"

# 7. Systemd Journal komprimieren
echo "📊 Komprimiere Systemd Journal..."
sudo journalctl --vacuum-time=1d
sudo journalctl --vacuum-size=10M
echo "✅ Journal komprimiert"

# 8. APT Cache leeren
echo "📦 Leere APT Cache..."
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
echo "✅ APT Cache geleert"

# 9. Swap deaktivieren (falls vorhanden)
echo "💾 Deaktiviere Swap..."
sudo swapoff -a
sudo rm -f /var/swap
echo "✅ Swap deaktiviert"

# 10. Dateisystem synchronisieren
echo "🔄 Synchronisiere Dateisystem..."
sync
echo "✅ Dateisystem synchronisiert"

# 11. Erstelle Image-Info Datei
echo "📄 Erstelle Image-Info..."
cat > /home/pi/MASTER-IMAGE-INFO.txt << EOF
🥧 Pi Manager Master Image
=========================

Erstellt: $(date)
Hostname: $(hostname)
IP: $(hostname -I | awk '{print $1}')
Node.js: $(node --version)
Pi Manager: Installiert und konfiguriert

Automatische Konfiguration beim ersten Boot:
- SSH Host Keys werden neu generiert
- Machine ID wird neu generiert
- DHCP Lease wird erneuert
- Pi Manager startet automatisch

Zugriff auf Pi Manager:
- Web Interface: http://<PI-IP>:3000
- Login: admin / admin123

Service Management:
- Status: sudo systemctl status pi-manager
- Restart: sudo systemctl restart pi-manager
- Logs: sudo journalctl -u pi-manager -f

Erstellt mit: Pi Manager Image Creation Tools
EOF

echo "✅ Image-Info erstellt"

# 12. Final Status
echo ""
echo "🎯 Image-Vorbereitung abgeschlossen!"
echo "=================================="
echo ""
echo "✅ System wurde für Image-Erstellung optimiert"
echo "✅ Pi Manager läuft und ist konfiguriert"
echo "✅ Temporäre Dateien wurden entfernt"
echo "✅ SSH Host Keys werden beim ersten Boot neu generiert"
echo "✅ Machine ID wird beim ersten Boot neu generiert"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Pi herunterfahren: sudo shutdown -h now"
echo "2. SD-Karte in Windows/Linux-Rechner einsetzen"
echo "3. Image-Erstellungs-Script ausführen"
echo ""
echo "🔧 Die SD-Karte ist jetzt bereit für die Image-Erstellung!"

echo ""
echo "⚠️  WICHTIG: Fahren Sie den Pi jetzt herunter:"
echo "   sudo shutdown -h now"
echo ""
echo "   Warten Sie bis die grüne LED nicht mehr blinkt,"
echo "   dann können Sie die SD-Karte entfernen."
