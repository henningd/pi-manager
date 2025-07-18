# 🥧 Pi Manager Master-Image Erstellung - Komplette Anleitung

## Ziel
Erstellen Sie ein wiederverwendbares Master-Image von Ihrer funktionierenden Pi Manager Installation, mit dem Sie schnell neue SD-Karten für weitere Raspberry Pis erstellen können.

## 📋 Voraussetzungen

### ✅ Erfolgreich getestet:
- [x] Pi Manager läuft unter http://192.168.60.112:3000
- [x] SSH-Zugang funktioniert (pi@192.168.60.112, Passwort: ecomo)
- [x] System ist vollständig konfiguriert

### 🛠️ Benötigte Tools (Windows):
- **Win32DiskImager** (empfohlen): https://sourceforge.net/projects/win32diskimager/
- **Oder Raspberry Pi Imager**: https://www.raspberrypi.org/software/
- **7-Zip** (optional für Komprimierung): https://www.7-zip.org/

## 🚀 Schritt-für-Schritt Anleitung

### Schritt 1: Pi für Image-Erstellung vorbereiten

**Auf dem Pi ausführen:**
```bash
# Vorbereitungs-Script erstellen
cat > /home/pi/prepare-image.sh << 'EOF'
#!/bin/bash
echo "🥧 Pi Manager - Image-Vorbereitung"
echo "=================================="

# Prüfe Pi Manager Status
if systemctl is-active --quiet pi-manager; then
    echo "✅ Pi Manager läuft - bereit für Image-Erstellung"
else
    echo "❌ Pi Manager läuft nicht - bitte zuerst reparieren"
    exit 1
fi

# Temporäre Dateien löschen
echo "🧹 Lösche temporäre Dateien..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo rm -rf /home/pi/.cache/*
sudo rm -rf /home/pi/.npm/_cacache/*
sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/log/*.log
sudo rm -rf /var/log/*/*.log

# SSH Host Keys löschen (werden beim ersten Boot neu generiert)
echo "🔐 Entferne SSH Host Keys..."
sudo rm -f /etc/ssh/ssh_host_*

# History löschen
echo "📝 Lösche History..."
rm -f /home/pi/.bash_history
sudo rm -f /root/.bash_history

# Machine ID löschen
echo "🆔 Entferne Machine ID..."
sudo truncate -s 0 /etc/machine-id
sudo truncate -s 0 /var/lib/dbus/machine-id

# DHCP Leases löschen
echo "🌐 Lösche DHCP Leases..."
sudo rm -f /var/lib/dhcp/*
sudo rm -f /var/lib/dhcpcd5/*

# APT Cache leeren
echo "📦 Leere APT Cache..."
sudo apt-get clean
sudo apt-get autoclean

# Erstelle Image-Info
echo "📄 Erstelle Image-Info..."
cat > /home/pi/MASTER-IMAGE-INFO.txt << EOL
🥧 Pi Manager Master Image
=========================

Erstellt: $(date)
Node.js: $(node --version)
Pi Manager: Installiert und konfiguriert

Web Interface: http://<PI-IP>:3000
Login: admin / admin123

SSH: pi@<PI-IP> (Passwort: ecomo)

Service: sudo systemctl status pi-manager
EOL

# Dateisystem synchronisieren
echo "🔄 Synchronisiere Dateisystem..."
sync

echo ""
echo "🎯 Pi ist bereit für Image-Erstellung!"
echo "======================================"
echo ""
echo "⚠️  WICHTIG: Fahren Sie den Pi jetzt herunter:"
echo "   sudo shutdown -h now"
echo ""
echo "Warten Sie bis die grüne LED nicht mehr blinkt,"
echo "dann können Sie die SD-Karte entfernen."
EOF

chmod +x /home/pi/prepare-image.sh
./prepare-image.sh
```

### Schritt 2: Pi herunterfahren
```bash
sudo shutdown -h now
```

**Warten Sie, bis die grüne LED nicht mehr blinkt, dann SD-Karte entfernen.**

### Schritt 3: SD-Karte in Windows-Rechner einsetzen

1. SD-Karte in Windows-Rechner einsetzen
2. Notieren Sie den Laufwerksbuchstaben (z.B. D:)

### Schritt 4: Master-Image erstellen

**Windows PowerShell als Administrator öffnen:**

```powershell
# Zur Projekt-Directory navigieren
cd "C:\Entwicklung\pi\image"

# Image-Erstellung starten (ersetzen Sie D durch Ihren Laufwerksbuchstaben)
.\scripts\create-master-image.ps1 -SourceDrive D

# Oder mit benutzerdefinierten Pfad:
.\scripts\create-master-image.ps1 -SourceDrive D -OutputPath "C:\PiImages\pi-manager-master.img"
```

**Der Prozess dauert 10-30 Minuten und erstellt:**
- `pi-manager-master.img` - Das Master-Image
- `pi-manager-master.img.gz` - Komprimierte Version
- `pi-manager-master.txt` - Image-Informationen

### Schritt 5: Neue SD-Karten aus Master-Image erstellen

**Mit Raspberry Pi Imager:**
1. Raspberry Pi Imager starten
2. "Use custom image" auswählen
3. Ihr Master-Image auswählen
4. Neue SD-Karte auswählen
5. "Write" klicken

**Mit Win32DiskImager:**
1. Win32DiskImager starten
2. Image-Datei auswählen
3. Neue SD-Karte auswählen
4. "Write" klicken

## 🔧 Automatisierter Workflow

### Für häufige Verwendung können Sie auch diesen Ein-Zeiler verwenden:

```bash
# Auf dem Pi (vorbereiten und herunterfahren)
curl -s https://raw.githubusercontent.com/your-repo/pi-manager-tools/main/prepare-and-shutdown.sh | bash
```

```powershell
# Auf Windows (Image erstellen)
.\scripts\create-master-image.ps1 -SourceDrive D -Compress
```

## 📊 Vorteile des Master-Images

### ✅ Jede neue SD-Karte hat:
- **Pi Manager vorinstalliert** - Kein manuelles Setup
- **SSH bereits aktiviert** - Sofortiger Zugriff
- **Deutsche Lokalisierung** - Timezone und Keyboard
- **Optimierte Konfiguration** - Bereit für den Einsatz

### ⚡ Deployment-Zeit:
- **Ohne Master-Image:** 30-60 Minuten pro Pi
- **Mit Master-Image:** 5-10 Minuten pro Pi

## 🔄 Workflow für neue Raspberry Pis

### 1. **SD-Karte flashen** (5 Minuten)
```
Master-Image → Neue SD-Karte → Raspberry Pi Imager
```

### 2. **Pi starten** (2 Minuten)
```
SD-Karte einsetzen → Ethernet anschließen → Power on
```

### 3. **Zugriff** (sofort)
```
http://<PI-IP>:3000
Login: admin / admin123
```

### 4. **SSH-Zugriff** (sofort)
```
ssh pi@<PI-IP>
Passwort: ecomo
```

## 🎯 Master-Image Verwaltung

### Image-Versionen verwalten:
```
pi-manager-master-v1.0.img    # Erste Version
pi-manager-master-v1.1.img    # Mit Updates
pi-manager-master-latest.img  # Aktuelle Version
```

### Image-Updates:
1. Basis-Pi mit Updates konfigurieren
2. Vorbereitungs-Script ausführen
3. Neues Master-Image erstellen
4. Alte Version archivieren

## 🔧 Troubleshooting

### Problem: "Drive not found"
**Lösung:** SD-Karte korrekt eingesetzt und von Windows erkannt?

### Problem: "Access denied"
**Lösung:** PowerShell als Administrator ausführen

### Problem: "Win32DiskImager not found"
**Lösung:** Win32DiskImager installieren oder Raspberry Pi Imager verwenden

### Problem: "Image too large"
**Lösung:** Komprimierung aktivieren (`-Compress`) oder größere SD-Karte verwenden

## 📋 Checkliste für Master-Image Erstellung

- [ ] Pi Manager funktioniert (http://<PI-IP>:3000)
- [ ] SSH-Zugang funktioniert
- [ ] Vorbereitungs-Script ausgeführt
- [ ] Pi korrekt heruntergefahren
- [ ] SD-Karte in Windows-Rechner eingesetzt
- [ ] PowerShell als Administrator gestartet
- [ ] Image-Erstellungs-Script ausgeführt
- [ ] Image erfolgreich erstellt
- [ ] Test-Deployment auf neuer SD-Karte durchgeführt

## 🎉 Ergebnis

**Sie haben jetzt:**
- ✅ Ein wiederverwendbares Master-Image
- ✅ Schnelles Deployment neuer Raspberry Pis
- ✅ Konsistente Pi Manager Installation
- ✅ Minimierte Setup-Zeit von Stunden auf Minuten

**Jeder neue Pi ist nach 5 Minuten einsatzbereit mit Pi Manager unter http://<PI-IP>:3000!**
