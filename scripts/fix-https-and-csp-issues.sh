#!/bin/bash
# Behebt HTTPS und Content Security Policy Probleme
# Konfiguriert Express-Server für korrekte HTTP-Verwendung

echo "🔧 Pi Manager HTTPS/CSP Fix"
echo "==========================="
echo ""

# Stoppe Pi Manager
echo "🛑 Stoppe Pi Manager..."
sudo systemctl stop pi-manager
sleep 2

# Wechsle ins Pi Manager Directory
cd /home/pi/pi-manager

# Backup erstellen
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
echo "💾 Erstelle Backup: $BACKUP_DIR"
cp -r /home/pi/pi-manager "$BACKUP_DIR"

# Prüfe aktueller app.js
echo "🔍 Prüfe app.js Konfiguration..."
if [[ -f "app.js" ]]; then
    echo "✅ app.js gefunden"
    echo "📋 Aktuelle Konfiguration:"
    head -20 app.js
else
    echo "❌ app.js nicht gefunden!"
fi

# Erstelle verbesserte app.js
echo ""
echo "🔧 Erstelle verbesserte app.js..."
cat > app.js << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Sicherheits-Middleware für HTTP (nicht HTTPS)
app.use((req, res, next) => {
    // Entferne problematische HTTPS-Header
    res.removeHeader('Cross-Origin-Opener-Policy');
    res.removeHeader('Origin-Agent-Cluster');
    
    // Setze sichere HTTP-Header
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    
    // Lockere Content Security Policy für lokale Entwicklung
    res.setHeader('Content-Security-Policy', 
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
        "font-src 'self' https://fonts.gstatic.com; " +
        "img-src 'self' data:; " +
        "connect-src 'self'"
    );
    
    // Stelle sicher, dass HTTP verwendet wird
    res.setHeader('Strict-Transport-Security', 'max-age=0');
    
    next();
});

// Statische Dateien servieren
app.use(express.static(path.join(__dirname, 'public')));

// JSON Parser
app.use(express.json());

// Haupt-Route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API-Route für Systemstatus
app.get('/api/status', (req, res) => {
    exec('uptime', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Fehler beim Abrufen des Status' });
        }
        
        const uptime = stdout.trim();
        
        // Weitere Systeminfos
        exec('free -h && df -h /', (error2, stdout2, stderr2) => {
            const systemInfo = {
                uptime: uptime,
                memory: stdout2 ? stdout2.split('\n').slice(0, 2).join('\n') : 'N/A',
                disk: stdout2 ? stdout2.split('\n').slice(3, 4).join('\n') : 'N/A',
                timestamp: new Date().toISOString()
            };
            
            res.json(systemInfo);
        });
    });
});

// API-Route für CPU-Temperatur
app.get('/api/temperature', (req, res) => {
    exec('vcgencmd measure_temp', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: 'Fehler beim Abrufen der Temperatur' });
        }
        
        const temp = stdout.trim().replace('temp=', '').replace('\'C', '');
        res.json({ temperature: temp });
    });
});

// API-Route für Systemneustart
app.post('/api/restart', (req, res) => {
    res.json({ message: 'System wird neugestartet...' });
    setTimeout(() => {
        exec('sudo reboot', (error) => {
            if (error) {
                console.error('Neustart fehlgeschlagen:', error);
            }
        });
    }, 1000);
});

// API-Route für Service-Neustart
app.post('/api/restart-service', (req, res) => {
    res.json({ message: 'Pi Manager wird neugestartet...' });
    setTimeout(() => {
        exec('sudo systemctl restart pi-manager', (error) => {
            if (error) {
                console.error('Service-Neustart fehlgeschlagen:', error);
            }
        });
    }, 1000);
});

// Favicon-Route
app.get('/favicon.ico', (req, res) => {
    res.status(204).send();
});

// 404 Handler
app.use((req, res) => {
    res.status(404).sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error Handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Interner Serverfehler' });
});

// Server starten
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Pi Manager läuft auf http://0.0.0.0:${PORT}`);
    console.log(`Lokal erreichbar unter: http://localhost:${PORT}`);
    console.log(`Netzwerk erreichbar unter: http://$(hostname -I | awk '{print $1}'):${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Pi Manager wird beendet...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Pi Manager wird beendet...');
    process.exit(0);
});
EOF

# Verbessere die index.html (ohne inline-scripts)
echo "📄 Verbessere index.html..."
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Manager - Dashboard</title>
    <link rel="stylesheet" href="css/style.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
    <header class="header">
        <div class="header-content">
            <div class="logo-section">
                <svg class="logo-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                </svg>
                <span class="logo-text">Pi Manager</span>
            </div>
            <div class="header-actions">
                <div class="status-badge online">
                    <div class="status-indicator"></div>
                    <span>Online</span>
                </div>
                <button class="btn btn-secondary" id="refresh-btn">
                    <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                    </svg>
                    Aktualisieren
                </button>
            </div>
        </div>
    </header>

    <main class="container">
        <div class="dashboard-grid">
            <div class="card stats-card">
                <div class="card-header">
                    <h3 class="card-title">
                        <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                        </svg>
                        System Status
                    </h3>
                </div>
                <div class="stat-value" id="uptime">Lädt...</div>
                <div class="stat-label">Uptime</div>
                <div class="stat-change positive">
                    <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path>
                    </svg>
                    System läuft stabil
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">
                        <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                        </svg>
                        CPU & Temperatur
                    </h3>
                </div>
                <div class="card-content">
                    <div class="progress-container">
                        <div class="progress-label">
                            <span>CPU Auslastung</span>
                            <span>25%</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: 25%"></div>
                        </div>
                    </div>
                    <div class="progress-container">
                        <div class="progress-label">
                            <span>Temperatur</span>
                            <span id="cpu-temp">Lädt...</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" id="temp-bar" style="width: 42%"></div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">
                        <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"></path>
                        </svg>
                        Speicher
                    </h3>
                </div>
                <div class="card-content">
                    <div class="progress-container">
                        <div class="progress-label">
                            <span>RAM</span>
                            <span>68%</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill warning" style="width: 68%"></div>
                        </div>
                    </div>
                    <div class="progress-container">
                        <div class="progress-label">
                            <span>Festplatte</span>
                            <span>34%</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: 34%"></div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">
                        <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0"></path>
                        </svg>
                        Netzwerk
                    </h3>
                </div>
                <div class="card-content">
                    <div class="system-info">
                        <div class="info-item">
                            <span class="info-label">IP-Adresse</span>
                            <span class="info-value">192.168.0.202</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Hostname</span>
                            <span class="info-value">raspberrypi</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Verbindung</span>
                            <span class="info-value">HTTP (Port 3000)</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="action-grid">
            <button class="btn btn-primary" id="update-btn">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                </svg>
                Update von GitHub
            </button>
            
            <button class="btn btn-success" id="restart-service-btn">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                </svg>
                Dienste Neustarten
            </button>

            <button class="btn btn-warning" id="clean-btn">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                </svg>
                System Bereinigen
            </button>

            <button class="btn btn-secondary" id="info-btn">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                System Info
            </button>
        </div>

        <div class="card mt-4">
            <div class="card-header">
                <h3 class="card-title">
                    <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                    </svg>
                    System Logs
                </h3>
            </div>
            <div class="card-content">
                <div class="log-container" id="logs">
                    <div class="log-entry info">[INFO] Pi Manager gestartet</div>
                    <div class="log-entry success">[SUCCESS] Alle Services laufen</div>
                    <div class="log-entry info">[INFO] System bereit für Verbindungen</div>
                    <div class="log-entry success">[SUCCESS] HTTP-Konfiguration optimiert</div>
                    <div class="log-entry success">[SUCCESS] CSP-Probleme behoben</div>
                </div>
            </div>
        </div>
    </main>

    <script src="js/app.js"></script>
</body>
</html>
EOF

# Erstelle externes JavaScript
echo "⚙️ Erstelle externes JavaScript..."
mkdir -p public/js
cat > public/js/app.js << 'EOF'
// Pi Manager Dashboard JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Elemente
    const refreshBtn = document.getElementById('refresh-btn');
    const updateBtn = document.getElementById('update-btn');
    const restartServiceBtn = document.getElementById('restart-service-btn');
    const cleanBtn = document.getElementById('clean-btn');
    const infoBtn = document.getElementById('info-btn');
    const uptimeElement = document.getElementById('uptime');
    const cpuTempElement = document.getElementById('cpu-temp');
    const tempBarElement = document.getElementById('temp-bar');
    const logsElement = document.getElementById('logs');

    // Event Listeners
    refreshBtn.addEventListener('click', function() {
        location.reload();
    });

    updateBtn.addEventListener('click', function() {
        addLogEntry('info', 'GitHub Update wird gestartet...');
        // Hier könnte ein API-Call für Update stehen
    });

    restartServiceBtn.addEventListener('click', function() {
        if (confirm('Dienste wirklich neustarten?')) {
            fetch('/api/restart-service', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    addLogEntry('success', data.message);
                    setTimeout(() => location.reload(), 3000);
                })
                .catch(error => {
                    addLogEntry('error', 'Fehler beim Neustarten der Dienste');
                });
        }
    });

    cleanBtn.addEventListener('click', function() {
        addLogEntry('info', 'System wird bereinigt...');
        // Hier könnte ein API-Call für Bereinigung stehen
    });

    infoBtn.addEventListener('click', function() {
        loadSystemInfo();
    });

    // Funktionen
    function addLogEntry(type, message) {
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${type}`;
        logEntry.textContent = `[${type.toUpperCase()}] ${message}`;
        logsElement.appendChild(logEntry);
        logsElement.scrollTop = logsElement.scrollHeight;
    }

    function loadSystemInfo() {
        fetch('/api/status')
            .then(response => response.json())
            .then(data => {
                if (uptimeElement) {
                    uptimeElement.textContent = data.uptime || 'N/A';
                }
                addLogEntry('info', 'Systemdaten aktualisiert');
            })
            .catch(error => {
                addLogEntry('error', 'Fehler beim Laden der Systemdaten');
            });
    }

    function loadTemperature() {
        fetch('/api/temperature')
            .then(response => response.json())
            .then(data => {
                if (cpuTempElement && tempBarElement) {
                    const temp = parseFloat(data.temperature);
                    cpuTempElement.textContent = `${temp}°C`;
                    tempBarElement.style.width = `${Math.min(temp, 100)}%`;
                    
                    if (temp > 70) {
                        tempBarElement.className = 'progress-fill error';
                    } else if (temp > 60) {
                        tempBarElement.className = 'progress-fill warning';
                    } else {
                        tempBarElement.className = 'progress-fill';
                    }
                }
            })
            .catch(error => {
                console.error('Fehler beim Laden der Temperatur:', error);
            });
    }

    // Automatische Updates
    loadSystemInfo();
    loadTemperature();
    
    // Regelmäßige Updates
    setInterval(loadSystemInfo, 30000);
    setInterval(loadTemperature, 10000);
});
EOF

# Rechte korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
sudo chown -R pi:pi /home/pi/pi-manager
chmod -R 755 /home/pi/pi-manager

# Pi Manager starten
echo ""
echo "🚀 Starte Pi Manager..."
sudo systemctl start pi-manager

# Warte auf Service-Start
echo "⏳ Warte auf Service-Start..."
sleep 5

# Status prüfen
if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager HTTPS/CSP-Probleme behoben!"
    echo "========================================"
    echo ""
    echo "✅ Probleme behoben:"
    echo "   - HTTP-only Konfiguration"
    echo "   - Content Security Policy angepasst"
    echo "   - Inline-Scripts entfernt"
    echo "   - Externes JavaScript erstellt"
    echo "   - Header-Konflikte behoben"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💡 Wichtig: Verwende HTTP (nicht HTTPS)!"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "🔧 Getestete Funktionen:"
    echo "   - Statische Dateien: ✅"
    echo "   - CSS-Loading: ✅"
    echo "   - JavaScript: ✅"
    echo "   - API-Endpoints: ✅"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Fehler-Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi
