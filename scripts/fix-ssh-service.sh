#!/bin/bash
# SSH Service Diagnose und Reparatur Script für Raspberry Pi

echo "🔒 SSH Service Diagnose und Reparatur"
echo "===================================="
echo ""

# Prüfe aktuellen Benutzer
ACTUAL_USER=${SUDO_USER:-$USER}
echo "👤 Aktueller Benutzer: $ACTUAL_USER"
echo ""

# 1. SSH Service Status prüfen
echo "📊 SSH Service Status:"
if systemctl is-active --quiet ssh; then
    echo "✅ SSH Service ist aktiv"
    systemctl status ssh --no-pager
else
    echo "❌ SSH Service ist nicht aktiv"
    echo "📝 Detaillierter Status:"
    systemctl status ssh --no-pager
fi
echo ""

# 2. SSH Installation prüfen
echo "🔍 SSH Installation prüfen:"
if dpkg -l | grep -q openssh-server; then
    echo "✅ OpenSSH Server ist installiert"
    dpkg -l | grep openssh-server
else
    echo "❌ OpenSSH Server ist nicht installiert"
    echo "📦 Installiere OpenSSH Server..."
    apt-get update
    apt-get install -y openssh-server
    echo "✅ OpenSSH Server installiert"
fi
echo ""

# 3. SSH-Konfiguration prüfen
echo "⚙️ SSH-Konfiguration prüfen:"
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
    echo "✅ SSH-Konfigurationsdatei gefunden"
    
    # Backup erstellen
    cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📋 Backup erstellt: $SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Wichtige Konfigurationen prüfen
    echo "🔍 Wichtige SSH-Einstellungen:"
    
    # Port
    if grep -q "^Port " "$SSH_CONFIG"; then
        echo "   Port: $(grep "^Port " "$SSH_CONFIG")"
    else
        echo "   Port: 22 (Standard)"
    fi
    
    # PermitRootLogin
    if grep -q "^PermitRootLogin " "$SSH_CONFIG"; then
        echo "   Root Login: $(grep "^PermitRootLogin " "$SSH_CONFIG")"
    else
        echo "   Root Login: nicht konfiguriert"
    fi
    
    # PasswordAuthentication
    if grep -q "^PasswordAuthentication " "$SSH_CONFIG"; then
        echo "   Password Auth: $(grep "^PasswordAuthentication " "$SSH_CONFIG")"
    else
        echo "   Password Auth: nicht konfiguriert"
    fi
    
else
    echo "❌ SSH-Konfigurationsdatei nicht gefunden"
fi
echo ""

# 4. SSH-Konfiguration reparieren
echo "🔧 SSH-Konfiguration reparieren:"

# Erstelle eine funktionierende SSH-Konfiguration
cat > "$SSH_CONFIG" << 'EOF'
# SSH Configuration - Raspberry Pi optimiert
# Backup der originalen Konfiguration wurde erstellt

# Basis-Einstellungen
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Sicherheitseinstellungen
PermitRootLogin no
MaxAuthTries 3
MaxStartups 10:30:60
LoginGraceTime 60

# Authentifizierung
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Benutzer und Gruppen
AllowUsers pi
AllowGroups pi sudo

# Netzwerk-Einstellungen
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Session-Einstellungen
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
UsePrivilegeSeparation sandbox

# Syslog
SyslogFacility AUTH
LogLevel INFO

# SFTP
Subsystem sftp /usr/lib/openssh/sftp-server

# Banner (optional)
#Banner /etc/issue.net
EOF

echo "✅ SSH-Konfiguration aktualisiert"

# 5. SSH Host Keys prüfen und neu generieren wenn nötig
echo "🔑 SSH Host Keys prüfen:"
SSH_KEYS_DIR="/etc/ssh"
HOST_KEYS=("ssh_host_rsa_key" "ssh_host_dsa_key" "ssh_host_ecdsa_key" "ssh_host_ed25519_key")

for key in "${HOST_KEYS[@]}"; do
    if [ -f "$SSH_KEYS_DIR/$key" ]; then
        echo "✅ $key vorhanden"
    else
        echo "❌ $key fehlt - wird neu generiert"
        case $key in
            "ssh_host_rsa_key")
                ssh-keygen -t rsa -b 2048 -f "$SSH_KEYS_DIR/$key" -N "" -q
                ;;
            "ssh_host_dsa_key")
                ssh-keygen -t dsa -f "$SSH_KEYS_DIR/$key" -N "" -q
                ;;
            "ssh_host_ecdsa_key")
                ssh-keygen -t ecdsa -f "$SSH_KEYS_DIR/$key" -N "" -q
                ;;
            "ssh_host_ed25519_key")
                ssh-keygen -t ed25519 -f "$SSH_KEYS_DIR/$key" -N "" -q
                ;;
        esac
        echo "✅ $key neu generiert"
    fi
done

# Host Keys Berechtigungen korrigieren
chmod 600 "$SSH_KEYS_DIR"/ssh_host_*_key
chmod 644 "$SSH_KEYS_DIR"/ssh_host_*_key.pub
chown root:root "$SSH_KEYS_DIR"/ssh_host_*

echo ""

# 6. SSH Service aktivieren und starten
echo "🚀 SSH Service aktivieren und starten:"

# Systemd neu laden
systemctl daemon-reload

# SSH aktivieren
systemctl enable ssh
echo "✅ SSH Service aktiviert"

# SSH starten
if systemctl start ssh; then
    echo "✅ SSH Service gestartet"
else
    echo "❌ SSH Service konnte nicht gestartet werden"
    echo "📝 Fehlerdetails:"
    journalctl -u ssh -n 20 --no-pager
fi

# Kurz warten
sleep 3

# 7. Port-Verfügbarkeit prüfen
echo ""
echo "🔍 Port 22 Verfügbarkeit:"
if netstat -tlnp | grep -q ":22 "; then
    echo "✅ Port 22 ist geöffnet"
    netstat -tlnp | grep ":22 "
else
    echo "❌ Port 22 ist nicht geöffnet"
fi

# 8. SSH-Test (lokal)
echo ""
echo "🧪 SSH-Verbindungstest:"
if echo "exit" | timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no localhost 2>/dev/null; then
    echo "✅ SSH-Verbindung erfolgreich"
else
    echo "⚠️  SSH-Verbindung fehlgeschlagen (normal wenn noch kein SSH-Key konfiguriert)"
fi

# 9. SSH für pi-Benutzer konfigurieren
echo ""
echo "👤 SSH für pi-Benutzer konfigurieren:"
PI_HOME="/home/pi"
SSH_DIR="$PI_HOME/.ssh"

if [ "$ACTUAL_USER" = "pi" ] || [ -d "$PI_HOME" ]; then
    # SSH-Directory erstellen
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        echo "✅ SSH-Directory erstellt: $SSH_DIR"
    fi
    
    # Berechtigungen korrigieren
    chown -R pi:pi "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    
    # authorized_keys erstellen falls nicht vorhanden
    if [ ! -f "$SSH_DIR/authorized_keys" ]; then
        touch "$SSH_DIR/authorized_keys"
        chmod 600 "$SSH_DIR/authorized_keys"
        chown pi:pi "$SSH_DIR/authorized_keys"
        echo "✅ authorized_keys Datei erstellt"
    fi
    
    echo "✅ SSH-Konfiguration für pi-Benutzer abgeschlossen"
else
    echo "⚠️  pi-Benutzer nicht gefunden"
fi

# 10. Firewall prüfen
echo ""
echo "🔥 Firewall-Status prüfen:"
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        echo "🔥 UFW Firewall ist aktiv"
        if ufw status | grep -q "22/tcp"; then
            echo "✅ SSH (Port 22) ist in der Firewall erlaubt"
        else
            echo "❌ SSH (Port 22) ist in der Firewall blockiert"
            echo "🔧 Erlaube SSH in der Firewall..."
            ufw allow ssh
            echo "✅ SSH in der Firewall erlaubt"
        fi
    else
        echo "✅ UFW Firewall ist nicht aktiv"
    fi
else
    echo "✅ UFW ist nicht installiert"
fi

# 11. Finaler Status
echo ""
echo "🎯 Finaler SSH-Status:"
echo "====================="

if systemctl is-active --quiet ssh; then
    echo "✅ SSH Service läuft erfolgreich!"
    
    # IP-Adresse ermitteln
    PI_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "🌐 SSH-Zugriff:"
    echo "   Remote: ssh pi@$PI_IP"
    echo "   Local:  ssh pi@localhost"
    echo ""
    echo "🔐 Standard-Anmeldedaten:"
    echo "   Username: pi"
    echo "   Password: [Ihr pi-Benutzer Passwort]"
    echo ""
    echo "🔧 SSH Service Management:"
    echo "   Status:  sudo systemctl status ssh"
    echo "   Logs:    sudo journalctl -u ssh -f"
    echo "   Restart: sudo systemctl restart ssh"
    echo "   Config:  sudo nano /etc/ssh/sshd_config"
    echo ""
    
    # SSH-Konfiguration testen
    echo "🧪 SSH-Konfiguration testen:"
    if sshd -t 2>/dev/null; then
        echo "✅ SSH-Konfiguration ist gültig"
    else
        echo "❌ SSH-Konfiguration enthält Fehler:"
        sshd -t
    fi
    
else
    echo "❌ SSH Service läuft nicht!"
    echo ""
    echo "🔍 Detaillierte Logs:"
    journalctl -u ssh -n 30 --no-pager
    echo ""
    echo "🔧 Manuelle Fehlerbehebung:"
    echo "   1. Logs prüfen: sudo journalctl -u ssh -f"
    echo "   2. Config testen: sudo sshd -t"
    echo "   3. Manual start: sudo systemctl start ssh"
    echo "   4. Config bearbeiten: sudo nano /etc/ssh/sshd_config"
fi

echo ""
echo "📋 Nächste Schritte:"
echo "   1. SSH-Verbindung testen: ssh pi@$PI_IP"
echo "   2. SSH-Keys einrichten (optional): ssh-keygen -t rsa"
echo "   3. SSH-Config anpassen (optional): sudo nano /etc/ssh/sshd_config"
echo ""
echo "🎉 SSH-Reparatur abgeschlossen!"
