# 🥧 Pi Manager SD-Karte Flash-Anleitung

## 📋 Benötigte Tools

1. **Raspberry Pi Imager** - Download: https://www.raspberrypi.org/software/
2. **SD-Karte** (mindestens 8GB) - Laufwerk D:
3. **Pi Manager Installation Script** (bereits vorbereitet)

## 🚀 Schritt-für-Schritt Anleitung

### 1. Raspberry Pi Imager installieren
- Lade Raspberry Pi Imager herunter und installiere es
- Starte das Programm

### 2. Image auswählen
- Klicke auf **"CHOOSE OS"**
- Wähle **"Raspberry Pi OS (other)"**
- Wähle **"Raspberry Pi OS Lite (32-bit)"**

### 3. SD-Karte auswählen
- Klicke auf **"CHOOSE STORAGE"**
- Wähle deine SD-Karte (Laufwerk D:)

### 4. Erweiterte Einstellungen konfigurieren
- Klicke auf das **Zahnrad-Symbol** (⚙️)
- **SSH aktivieren:**
  - ✅ Enable SSH
  - ✅ Use password authentication
  - Username: `pi`
  - Password: `ecomo`

- **Lokalisierung:**
  - ✅ Set locale settings
  - Time zone: `Europe/Berlin`
  - Keyboard layout: `de`

- **WLAN deaktivieren:**
  - ❌ Configure wireless LAN (leer lassen)

### 5. Image schreiben
- Klicke auf **"WRITE"**
- Bestätige mit **"YES"**
- Warte bis der Vorgang abgeschlossen ist (ca. 5-10 Minuten)

### 6. Pi Manager Installation vorbereiten
Nach dem Flash-Vorgang:

1. **SD-Karte nicht entfernen!**
2. Öffne den **boot**-Ordner der SD-Karte
3. Kopiere die Datei `install-pi-manager.sh` in den boot-Ordner:

```bash
# Inhalt der install-pi-manager.sh Datei:
#!/bin/bash
echo "🥧 Starting Pi Manager installation..."

# Update system
sudo apt update
sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs git

# Clone Pi Manager from GitHub
cd /home/pi
git clone https://github.com/henningd/pi-manager.git
cd pi-manager

# Install dependencies
npm install --production

# Set up service
sudo cp scripts/pi-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pi-manager
sudo systemctl start pi-manager

# Configure system
sudo timedatectl set-timezone Europe/Berlin

echo "✅ Pi Manager installation completed!"
echo "🌐 Access at: http://$(hostname -I | awk '{print $1}'):3000"
echo "🔐 Login: admin / admin123"
```

## 🔌 Pi Setup

### 1. Hardware anschließen
- SD-Karte in den Raspberry Pi einsetzen
- **Ethernet-Kabel** anschließen (wichtig!)
- Stromkabel anschließen

### 2. Ersten Boot abwarten
- Pi startet automatisch (ca. 2-3 Minuten)
- LED-Aktivität zeigt den Boot-Vorgang

### 3. IP-Adresse finden
**Option A - Router-Interface:**
- Öffne dein Router-Interface
- Suche nach "raspberrypi" in der Geräteliste

**Option B - Ping-Test:**
```cmd
ping raspberrypi.local
```

**Option C - IP-Scanner:**
- Verwende einen Netzwerk-Scanner wie "Advanced IP Scanner"

### 4. SSH-Verbindung herstellen
```cmd
ssh pi@[PI-IP-ADRESSE]
```
- Passwort: `ecomo`
- Bei der ersten Verbindung mit "yes" bestätigen

### 5. Pi Manager installieren
```bash
# Installation script ausführbar machen
chmod +x /boot/install-pi-manager.sh

# Installation starten
sudo /boot/install-pi-manager.sh
```

Die Installation dauert ca. 5-10 Minuten.

## 🌐 Pi Manager verwenden

### Web-Interface öffnen
```
http://[PI-IP-ADRESSE]:3000
```

### Standard-Anmeldedaten
- **Benutzername:** `admin`
- **Passwort:** `admin123`

⚠️ **Wichtig:** Ändere das Passwort nach der ersten Anmeldung!

## 🔧 Fehlerbehebung

### Pi bootet nicht
- SD-Karte korrekt eingesetzt?
- Stromversorgung ausreichend (min. 2.5A)?
- LED-Aktivität vorhanden?

### Keine Netzwerkverbindung
- Ethernet-Kabel korrekt angeschlossen?
- Router-Verbindung aktiv?
- DHCP im Router aktiviert?

### SSH-Verbindung fehlschlägt
- IP-Adresse korrekt?
- SSH in den erweiterten Einstellungen aktiviert?
- Passwort "ecomo" korrekt eingegeben?

### Pi Manager startet nicht
```bash
# Service-Status prüfen
sudo systemctl status pi-manager

# Service neu starten
sudo systemctl restart pi-manager

# Logs anzeigen
sudo journalctl -u pi-manager -f
```

## 🎉 Fertig!

Dein Raspberry Pi ist jetzt mit Pi Manager konfiguriert und einsatzbereit!

**Nächste Schritte:**
1. Passwort ändern
2. WLAN über das Web-Interface konfigurieren
3. System-Monitoring nutzen
4. Automatische Updates aktivieren

---

**Bei Problemen:** Prüfe die Logs oder starte den Pi neu.
