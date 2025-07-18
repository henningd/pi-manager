# 🔒 SSH Service Reparatur - Anleitung

## Problem
Der SSH-Service (OpenBSD Secure Shell server) kann nicht gestartet werden.

## ⚡ Sofortlösung

### 1. Script auf den Raspberry Pi übertragen
```bash
# Option A: Direkt auf dem Pi erstellen
sudo nano /home/pi/fix-ssh-service.sh
# (Inhalt aus scripts/fix-ssh-service.sh kopieren)

# Option B: Mit scp übertragen (falls anderer Pi erreichbar)
scp scripts/fix-ssh-service.sh pi@<PI-IP>:/home/pi/

# Option C: Mit USB-Stick übertragen
# Script auf USB-Stick kopieren und am Pi einstecken
```

### 2. Script ausführbar machen und ausführen
```bash
# Script ausführbar machen
chmod +x /home/pi/fix-ssh-service.sh

# Script als root ausführen (für systemd und Konfigurationsänderungen)
sudo /home/pi/fix-ssh-service.sh
```

### 3. Alternativer Schnellfix (falls Script nicht verfügbar)
```bash
# SSH Service neu installieren
sudo apt-get update
sudo apt-get install --reinstall openssh-server

# SSH Service aktivieren und starten
sudo systemctl enable ssh
sudo systemctl start ssh

# Status prüfen
sudo systemctl status ssh
```

## 🔍 Das Script macht folgendes:

1. **Diagnose**: Prüft SSH-Installation und -Konfiguration
2. **Installation**: Installiert OpenSSH Server falls nicht vorhanden
3. **Konfiguration**: Erstellt optimierte SSH-Konfiguration
4. **Host Keys**: Generiert fehlende SSH-Host-Keys
5. **Service**: Aktiviert und startet den SSH-Service
6. **Firewall**: Prüft und konfiguriert Firewall-Regeln
7. **Test**: Testet SSH-Verbindung

## 📋 Häufige SSH-Probleme und Lösungen

### Problem: "ssh: connect to host port 22: Connection refused"
```bash
# Service-Status prüfen
sudo systemctl status ssh

# Service starten
sudo systemctl start ssh

# Port prüfen
sudo netstat -tlnp | grep :22
```

### Problem: "Host key verification failed"
```bash
# Host Keys neu generieren
sudo rm /etc/ssh/ssh_host_*
sudo ssh-keygen -A

# SSH Service neu starten
sudo systemctl restart ssh
```

### Problem: "Permission denied (publickey)"
```bash
# Password-Authentifizierung aktivieren
sudo nano /etc/ssh/sshd_config
# Zeile ändern: PasswordAuthentication yes

# SSH Service neu starten
sudo systemctl restart ssh
```

### Problem: "Could not load host key"
```bash
# Host Keys manuell generieren
sudo ssh-keygen -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N ""
sudo ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ""
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# Berechtigungen korrigieren
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub
```

## 🛠️ Manuelle Fehlerbehebung

### 1. SSH-Logs anzeigen
```bash
# Aktuelle Logs
sudo journalctl -u ssh -f

# Letzte 50 Einträge
sudo journalctl -u ssh -n 50
```

### 2. SSH-Konfiguration testen
```bash
# Konfiguration auf Syntax-Fehler prüfen
sudo sshd -t

# Detaillierte Prüfung
sudo sshd -T
```

### 3. SSH im Debug-Modus starten
```bash
# SSH Service stoppen
sudo systemctl stop ssh

# SSH im Debug-Modus starten
sudo /usr/sbin/sshd -D -d
```

### 4. Network-Konfiguration prüfen
```bash
# Netzwerk-Interfaces anzeigen
ip addr show

# Routing-Tabelle anzeigen
ip route show

# DNS-Auflösung testen
nslookup google.com
```

## 🌐 Nach erfolgreicher Reparatur

### SSH-Verbindung testen
```bash
# Lokal testen
ssh pi@localhost

# Remote testen (von anderem Computer)
ssh pi@<PI-IP-ADRESSE>
```

### SSH-Key Authentifizierung einrichten (optional)
```bash
# SSH-Key generieren (auf Client-Computer)
ssh-keygen -t rsa -b 2048

# Public Key auf Pi kopieren
ssh-copy-id pi@<PI-IP-ADRESSE>

# Oder manuell:
scp ~/.ssh/id_rsa.pub pi@<PI-IP>:/home/pi/
ssh pi@<PI-IP>
cat ~/id_rsa.pub >> ~/.ssh/authorized_keys
```

### SSH-Konfiguration anpassen (optional)
```bash
# SSH-Konfiguration bearbeiten
sudo nano /etc/ssh/sshd_config

# Wichtige Einstellungen:
# Port 22                    # SSH-Port ändern
# PermitRootLogin no         # Root-Login deaktivieren
# PasswordAuthentication yes # Password-Auth erlauben
# PubkeyAuthentication yes   # Key-Auth erlauben

# Nach Änderungen SSH neu starten
sudo systemctl restart ssh
```

## 🔒 Sicherheitsempfehlungen

1. **Standard-Port ändern**: Port 22 auf andere Nummer ändern
2. **Root-Login deaktivieren**: `PermitRootLogin no`
3. **SSH-Keys verwenden**: Schlüssel-basierte Authentifizierung
4. **Fail2Ban installieren**: Schutz vor Brute-Force-Attacken
5. **UFW Firewall aktivieren**: Nur benötigte Ports öffnen

## 📊 SSH-Status überwachen

```bash
# Service-Status
sudo systemctl status ssh

# SSH-Verbindungen anzeigen
sudo netstat -tn | grep :22

# Aktive SSH-Sessions
who

# SSH-Logs überwachen
sudo journalctl -u ssh -f
```

## 🎉 Erfolg?

Nach erfolgreicher SSH-Reparatur sollten Sie:

1. ✅ SSH-Service läuft (`systemctl status ssh`)
2. ✅ Port 22 ist geöffnet (`netstat -tlnp | grep :22`)
3. ✅ SSH-Verbindung funktioniert (`ssh pi@<PI-IP>`)
4. ✅ SSH-Konfiguration ist gültig (`sudo sshd -t`)

**Jetzt können Sie remote auf Ihren Pi zugreifen! 🚀**
