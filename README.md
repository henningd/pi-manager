# 🥧 Pi Manager - Raspberry Pi Remote Management System

Ein umfassendes Remote-Management-System für Raspberry Pi mit deutscher Lokalisierung, automatischen Updates und Benachrichtigungen.

## ✨ Features

### 🖥️ System-Überwachung
- **Real-time Status**: CPU, Memory, Temperatur, Uptime
- **Online/Offline Erkennung**: Automatische Benachrichtigungen bei Statusänderungen
- **System Health Monitoring**: Warnung bei kritischen Werten
- **WebSocket-basierte Live-Updates**: Echtzeitdaten im Dashboard

### 🔄 Remote Control
- **System Neustart/Herunterfahren**: Sichere Remote-Steuerung
- **Automatische Benachrichtigungen**: Vor Offline-Gehen und nach Online-Kommen
- **Graceful Shutdown**: Ordnungsgemäße Beendigung aller Services

### 📡 Benachrichtigungssystem
- **HTTP Webhook Support**: POST-Benachrichtigungen an externe Systeme
- **Heartbeat-Monitoring**: Regelmäßige Lebenszeichen (alle 5 Minuten)
- **Status-Updates**: Detaillierte Systeminformationen (alle 15 Minuten)
- **Event-basierte Alerts**: Bei kritischen Systemereignissen

### 🔄 Automatische Updates
- **GitHub Integration**: Automatische Updates aus Repository
- **Konfigurierbare Intervalle**: Standard alle 2 Minuten prüfbar
- **Backup-System**: Automatische Sicherung vor Updates
- **Rollback-Funktion**: Bei fehlgeschlagenen Updates
- **Dependency Management**: Automatische npm install bei package.json Änderungen

### 🌐 Web-Interface
- **Responsive Design**: Optimiert für Desktop und Mobile
- **Deutsche Lokalisierung**: Vollständig auf Deutsch
- **Benutzerfreundlich**: Intuitive Bedienung
- **Sichere Authentifizierung**: JWT-basierte Anmeldung

### 🔒 Sicherheit
- **Benutzerauthentifizierung**: Sichere Login-Verwaltung
- **Passwort-Verschlüsselung**: bcrypt-Hashing
- **Rate Limiting**: Schutz vor Brute-Force-Angriffen
- **Helmet.js**: Zusätzliche HTTP-Sicherheitsheader

## 🚀 Installation

### Automatische Installation (Empfohlen)

1. **Repository klonen:**
   ```bash
   git clone <repository-url>
   cd pi-manager
   ```

2. **Installationsskript ausführen:**
   ```bash
   chmod +x scripts/install.sh
   ./scripts/install.sh
   ```

3. **Service-Status prüfen:**
   ```bash
   sudo systemctl status pi-manager
   ```

### Manuelle Installation

1. **Abhängigkeiten installieren:**
   ```bash
   sudo apt update
   sudo apt install -y nodejs npm git sqlite3
   ```

2. **Repository klonen:**
   ```bash
   git clone <repository-url>
   cd pi-manager
   ```

3. **Node.js Abhängigkeiten installieren:**
   ```bash
   npm install --production
   ```

4. **Systemd Service einrichten:**
   ```bash
   sudo cp scripts/pi-manager.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable pi-manager
   sudo systemctl start pi-manager
   ```

## 🖥️ SD-Karte erstellen

### Windows PowerShell Script

```powershell
# Als Administrator ausführen
.\scripts\flash-image.ps1 -DriveLetter D
```

Das Script:
- Lädt Raspberry Pi OS herunter
- Flasht das Image auf die SD-Karte
- Konfiguriert SSH und WiFi
- Bereitet Pi Manager für die Installation vor

## ⚙️ Konfiguration

### Erste Anmeldung

1. **Web-Interface öffnen:**
   ```
   http://<pi-ip-address>:3000
   ```

2. **Standard-Anmeldedaten:**
   - Benutzername: `admin`
   - Passwort: `admin123`

3. **⚠️ Passwort sofort ändern!**

### System-Konfiguration

#### Allgemeine Einstellungen
- **Gerätename**: Eindeutiger Name für Identifikation
- **Zeitzone**: Automatisch auf Europe/Berlin gesetzt
- **Tastaturlayout**: Automatisch auf Deutsch gesetzt

#### Benachrichtigungen
- **Webhook URL**: HTTP-Endpunkt für Benachrichtigungen
- **Benachrichtigungsformat**: JSON POST mit Geräteinformationen

Beispiel Webhook-Payload:
```json
{
  "device": "Raspberry Pi",
  "message": "System ist online",
  "type": "online",
  "timestamp": "2023-12-07T10:30:00.000Z",
  "status": "online"
}
```

#### Automatische Updates
- **GitHub Repository**: URL zum Repository mit Updates
- **Branch**: Standard "main"
- **Update-Intervall**: In Sekunden (Standard: 120)
- **Auto-Update**: Aktivieren für automatische Installation

#### Sicherheit
- **Passwort ändern**: Mindestens 6 Zeichen
- **Session-Management**: Automatische Abmeldung bei Inaktivität

## 🔧 API-Endpunkte

### Authentifizierung
```bash
# Anmelden
POST /auth/login
{
  "username": "admin",
  "password": "admin123"
}

# Token verifizieren
GET /auth/verify
Authorization: Bearer <token>
```

### System-Control
```bash
# System-Status abrufen
GET /api/status
Authorization: Bearer <token>

# System neu starten
POST /api/reboot
Authorization: Bearer <token>

# System herunterfahren
POST /api/shutdown
Authorization: Bearer <token>

# Test-Benachrichtigung senden
POST /api/test-notification
Authorization: Bearer <token>
{
  "message": "Test-Nachricht"
}
```

### Konfiguration
```bash
# Konfiguration abrufen
GET /api/config
Authorization: Bearer <token>

# Konfiguration aktualisieren
POST /api/config
Authorization: Bearer <token>
{
  "device_name": "Mein Pi",
  "notification_url": "https://example.com/webhook"
}
```

## 📊 Monitoring

### System-Metriken
- **CPU-Auslastung**: Load Average (1, 5, 15 Minuten)
- **Speicherverbrauch**: RAM-Nutzung in GB und Prozent
- **Temperatur**: CPU-Temperatur in °C (Raspberry Pi spezifisch)
- **Festplattenspeicher**: Verfügbarer Speicherplatz
- **Netzwerk**: Aktive Netzwerkschnittstellen

### Log-System
- **Strukturierte Logs**: Timestamp, Level, Message
- **Log-Level**: Info, Warning, Error
- **Web-Interface**: Live-Anzeige der letzten Logs
- **Systemd Journal**: Integration mit journalctl

## 🔄 Update-System

### Automatische Updates
1. **Repository-Überwachung**: Regelmäßige Prüfung auf neue Commits
2. **Backup-Erstellung**: Automatische Sicherung vor Update
3. **Git Pull**: Herunterladen der neuesten Änderungen
4. **Dependency-Check**: Prüfung auf package.json Änderungen
5. **Service-Neustart**: Automatischer Neustart nach Update
6. **Rollback**: Bei Fehlern automatische Wiederherstellung

### Manuelle Updates
```bash
# Update-Prüfung über API
POST /api/update-check
Authorization: Bearer <token>

# Oder über Kommandozeile
sudo systemctl restart pi-manager
```

## 🛠️ Entwicklung

### Lokale Entwicklung
```bash
# Development-Modus starten
npm run dev

# Tests ausführen
npm test

# Linting
npm run lint
```

### Projektstruktur
```
pi-manager/
├── app.js                 # Hauptanwendung
├── package.json           # Node.js Abhängigkeiten
├── config/               # Konfigurationsdateien
│   ├── database.js       # SQLite Datenbankconfig
│   └── auth.js          # Authentifizierung
├── routes/              # API-Routen
│   ├── auth.js         # Authentifizierungs-Routen
│   └── api.js          # System-API-Routen
├── services/           # Hintergrund-Services
│   ├── monitor.js      # System-Monitoring
│   ├── notifier.js     # Benachrichtigungssystem
│   └── updater.js      # Update-Management
├── public/             # Web-Interface
│   ├── index.html      # Dashboard
│   ├── login.html      # Login-Seite
│   ├── css/           # Stylesheets
│   └── js/            # JavaScript
└── scripts/           # Installations-/Setup-Skripte
    ├── install.sh     # Linux-Installation
    ├── flash-image.ps1 # Windows SD-Karten-Tool
    └── pi-manager.service # Systemd Service
```

## 🐛 Troubleshooting

### Service-Probleme
```bash
# Service-Status prüfen
sudo systemctl status pi-manager

# Logs anzeigen
sudo journalctl -u pi-manager -f

# Service neu starten
sudo systemctl restart pi-manager

# Service-Konfiguration neu laden
sudo systemctl daemon-reload
```

### Häufige Probleme

#### Port bereits in Verwendung
```bash
# Prozess auf Port 3000 finden
sudo lsof -i :3000

# Prozess beenden
sudo kill -9 <PID>
```

#### Berechtigungsprobleme
```bash
# Dateiberechtigungen korrigieren
sudo chown -R pi:pi /opt/pi-manager
sudo chmod +x /opt/pi-manager/scripts/install.sh
```

#### Datenbankprobleme
```bash
# Datenbank neu initialisieren
rm /opt/pi-manager/data/pi-manager.db
sudo systemctl restart pi-manager
```

## 📝 Changelog

### Version 1.0.0
- ✨ Initiale Veröffentlichung
- 🖥️ System-Monitoring Dashboard
- 🔄 Remote Reboot/Shutdown
- 📡 Webhook-Benachrichtigungen
- 🔄 Automatische GitHub-Updates
- 🌐 Deutsche Web-Oberfläche
- 🔒 Sichere Authentifizierung

## 🤝 Beitragen

1. Fork des Repositories erstellen
2. Feature-Branch erstellen (`git checkout -b feature/AmazingFeature`)
3. Änderungen committen (`git commit -m 'Add some AmazingFeature'`)
4. Branch pushen (`git push origin feature/AmazingFeature`)
5. Pull Request erstellen

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe `LICENSE` Datei für Details.

## 🆘 Support

Bei Problemen oder Fragen:

1. **GitHub Issues**: Für Bug-Reports und Feature-Requests
2. **Dokumentation**: Diese README-Datei
3. **Logs**: `sudo journalctl -u pi-manager -f`

## 🙏 Danksagungen

- Raspberry Pi Foundation für die großartige Hardware
- Node.js Community für die verwendeten Pakete
- Alle Mitwirkenden und Tester

---

**🥧 Pi Manager - Ihr Raspberry Pi, immer unter Kontrolle!**
