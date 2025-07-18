#!/bin/bash
# Fügt eindeutige Pi-Hardware-Informationen zum Dashboard hinzu
# Zeigt Modell, Seriennummer, MAC-Adresse und weitere Hardware-Details an

echo "🔍 Pi Manager Hardware-Info Setup"
echo "================================="
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

# Erweiterte app.js mit Hardware-Info APIs
echo "🔧 Erweitere app.js mit Hardware-Info APIs..."
cat > app.js << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const https = require('https');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// GitHub Repository Info
const GITHUB_REPO = 'henningd/pi-manager';
const GITHUB_API_URL = `https://api.github.com/repos/${GITHUB_REPO}`;

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

// Hilfsfunktionen für System-Informationen
function executeCommand(command) {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout.trim());
            }
        });
    });
}

function readFile(filePath) {
    return new Promise((resolve, reject) => {
        fs.readFile(filePath, 'utf8', (err, data) => {
            if (err) {
                reject(err);
            } else {
                resolve(data.trim());
            }
        });
    });
}

// Hilfsfunktionen für GitHub API
function fetchGitHubData(endpoint) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.github.com',
            port: 443,
            path: endpoint,
            method: 'GET',
            headers: {
                'User-Agent': 'Pi-Manager/1.0',
                'Accept': 'application/vnd.github.v3+json'
            }
        };

        const req = https.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                if (res.statusCode === 200) {
                    try {
                        resolve(JSON.parse(data));
                    } catch (e) {
                        reject(e);
                    }
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(10000, () => {
            req.abort();
            reject(new Error('GitHub API Timeout'));
        });

        req.end();
    });
}

function getCurrentCommitHash() {
    return new Promise((resolve, reject) => {
        exec('git rev-parse HEAD', (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout.trim());
            }
        });
    });
}

function getCurrentBranch() {
    return new Promise((resolve, reject) => {
        exec('git branch --show-current', (error, stdout, stderr) => {
            if (error) {
                reject(error);
            } else {
                resolve(stdout.trim());
            }
        });
    });
}

// Haupt-Route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API-Route für Pi Hardware-Informationen
app.get('/api/pi-hardware', async (req, res) => {
    try {
        const hardwareInfo = {
            // Grundlegende Pi-Informationen
            model: 'Unbekannt',
            serialNumber: 'Unbekannt',
            macAddress: 'Unbekannt',
            hostname: os.hostname(),
            platform: os.platform(),
            arch: os.arch(),
            
            // CPU-Informationen
            cpu: {
                model: 'Unbekannt',
                cores: os.cpus().length,
                speed: 'Unbekannt'
            },
            
            // Speicher-Informationen
            memory: {
                total: Math.round(os.totalmem() / 1024 / 1024 / 1024 * 100) / 100 + ' GB',
                free: Math.round(os.freemem() / 1024 / 1024 / 1024 * 100) / 100 + ' GB',
                used: Math.round((os.totalmem() - os.freemem()) / 1024 / 1024 / 1024 * 100) / 100 + ' GB'
            },
            
            // Netzwerk-Informationen
            network: {
                interfaces: {}
            },
            
            // System-Informationen
            system: {
                uptime: Math.floor(os.uptime()),
                bootTime: new Date(Date.now() - os.uptime() * 1000).toISOString(),
                loadAverage: os.loadavg()
            }
        };

        // Pi-Modell aus /proc/cpuinfo
        try {
            const cpuInfo = await readFile('/proc/cpuinfo');
            const modelMatch = cpuInfo.match(/Model\s*:\s*(.+)/);
            if (modelMatch) {
                hardwareInfo.model = modelMatch[1];
            }
            
            const revisionMatch = cpuInfo.match(/Revision\s*:\s*(.+)/);
            if (revisionMatch) {
                hardwareInfo.revision = revisionMatch[1];
            }
            
            const serialMatch = cpuInfo.match(/Serial\s*:\s*(.+)/);
            if (serialMatch) {
                hardwareInfo.serialNumber = serialMatch[1];
            }
            
            const processorMatch = cpuInfo.match(/processor\s*:\s*(.+)/);
            if (processorMatch) {
                hardwareInfo.cpu.model = cpuInfo.match(/model name\s*:\s*(.+)/)?.[1] || 'ARM Processor';
            }
        } catch (error) {
            console.error('Fehler beim Lesen der CPU-Info:', error);
        }

        // MAC-Adresse der primären Netzwerkschnittstelle
        const networkInterfaces = os.networkInterfaces();
        for (const [name, interfaces] of Object.entries(networkInterfaces)) {
            if (interfaces) {
                for (const iface of interfaces) {
                    if (!iface.internal && iface.family === 'IPv4') {
                        hardwareInfo.network.interfaces[name] = {
                            ip: iface.address,
                            mac: iface.mac,
                            netmask: iface.netmask
                        };
                        
                        // Setze die erste externe Interface als primäre MAC
                        if (hardwareInfo.macAddress === 'Unbekannt') {
                            hardwareInfo.macAddress = iface.mac;
                        }
                    }
                }
            }
        }

        // Zusätzliche Hardware-Informationen
        try {
            // Boot-Konfiguration
            const bootConfig = await readFile('/boot/config.txt').catch(() => 'N/A');
            hardwareInfo.bootConfig = bootConfig.split('\n').filter(line => 
                line.trim() && !line.startsWith('#')
            ).slice(0, 10); // Erste 10 aktive Zeilen

            // Festplatten-Informationen
            const diskInfo = await executeCommand('df -h').catch(() => 'N/A');
            hardwareInfo.disk = diskInfo;

            // USB-Geräte
            const usbDevices = await executeCommand('lsusb').catch(() => 'N/A');
            hardwareInfo.usbDevices = usbDevices.split('\n').filter(line => line.trim());

            // GPU-Speicher
            const gpuMemory = await executeCommand('vcgencmd get_mem gpu').catch(() => 'N/A');
            hardwareInfo.gpuMemory = gpuMemory.replace('gpu=', '');

            // Pi-spezifische Informationen
            const throttled = await executeCommand('vcgencmd get_throttled').catch(() => 'N/A');
            hardwareInfo.throttled = throttled.replace('throttled=', '');

            // Firmware-Version
            const firmwareVersion = await executeCommand('vcgencmd version').catch(() => 'N/A');
            hardwareInfo.firmwareVersion = firmwareVersion.split('\n')[0];

            // Betriebssystem-Details
            const osRelease = await readFile('/etc/os-release').catch(() => 'N/A');
            const osInfo = {};
            osRelease.split('\n').forEach(line => {
                const [key, value] = line.split('=');
                if (key && value) {
                    osInfo[key] = value.replace(/"/g, '');
                }
            });
            hardwareInfo.os = osInfo;

        } catch (error) {
            console.error('Fehler beim Sammeln zusätzlicher Hardware-Informationen:', error);
        }

        res.json(hardwareInfo);
    } catch (error) {
        console.error('Hardware-Info Fehler:', error);
        res.status(500).json({ 
            error: 'Fehler beim Sammeln der Hardware-Informationen',
            details: error.message 
        });
    }
});

// API-Route für Update-Check
app.get('/api/check-updates', async (req, res) => {
    try {
        // Aktueller Branch und Commit
        const currentBranch = await getCurrentBranch();
        const currentCommit = await getCurrentCommitHash();
        
        // GitHub API: Neueste Commits vom aktuellen Branch
        const commitsData = await fetchGitHubData(`/repos/${GITHUB_REPO}/commits?sha=${currentBranch}&per_page=1`);
        
        if (commitsData && commitsData.length > 0) {
            const latestCommit = commitsData[0];
            const latestCommitHash = latestCommit.sha;
            const latestCommitMessage = latestCommit.commit.message;
            const latestCommitDate = new Date(latestCommit.commit.author.date);
            
            // Prüfe ob Update verfügbar
            const updateAvailable = currentCommit !== latestCommitHash;
            
            // Zusätzliche Repository-Infos
            const repoData = await fetchGitHubData(`/repos/${GITHUB_REPO}`);
            
            const updateInfo = {
                updateAvailable: updateAvailable,
                currentBranch: currentBranch,
                currentCommit: currentCommit.substring(0, 7),
                currentCommitFull: currentCommit,
                latestCommit: latestCommitHash.substring(0, 7),
                latestCommitFull: latestCommitHash,
                latestCommitMessage: latestCommitMessage,
                latestCommitDate: latestCommitDate.toISOString(),
                commitsBehind: updateAvailable ? 1 : 0,
                repository: {
                    name: repoData.name,
                    description: repoData.description,
                    lastUpdated: repoData.updated_at,
                    stars: repoData.stargazers_count,
                    forks: repoData.forks_count
                }
            };
            
            res.json(updateInfo);
        } else {
            res.status(404).json({ error: 'Keine Commits gefunden' });
        }
    } catch (error) {
        console.error('Update-Check Fehler:', error);
        res.status(500).json({ 
            error: 'Fehler beim Prüfen auf Updates',
            details: error.message 
        });
    }
});

// API-Route für GitHub Update ausführen
app.post('/api/update-from-github', async (req, res) => {
    try {
        const currentBranch = await getCurrentBranch();
        
        res.json({ 
            message: 'GitHub Update wird gestartet...',
            branch: currentBranch 
        });
        
        // Update-Prozess im Hintergrund starten
        setTimeout(() => {
            exec(`git fetch origin && git reset --hard origin/${currentBranch}`, (error, stdout, stderr) => {
                if (error) {
                    console.error('Update-Fehler:', error);
                } else {
                    console.log('Update erfolgreich:', stdout);
                    // Pi Manager nach Update neustarten
                    setTimeout(() => {
                        exec('sudo systemctl restart pi-manager', (restartError) => {
                            if (restartError) {
                                console.error('Neustart-Fehler:', restartError);
                            }
                        });
                    }, 2000);
                }
            });
        }, 1000);
    } catch (error) {
        res.status(500).json({ 
            error: 'Fehler beim Starten des Updates',
            details: error.message 
        });
    }
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
    console.log(`GitHub Repository: ${GITHUB_REPO}`);
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

# Erweiterte index.html mit Hardware-Info-Sektion
echo "📄 Erweitere index.html mit Hardware-Informationen..."
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
                <div class="pi-identity">
                    <div class="pi-model" id="pi-model">Raspberry Pi</div>
                    <div class="pi-serial" id="pi-serial">SN: ...</div>
                </div>
                <div class="status-badge online">
                    <div class="status-indicator"></div>
                    <span>Online</span>
                </div>
                <div id="update-notification" class="update-notification hidden">
                    <svg class="update-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                    </svg>
                    <span>Update verfügbar!</span>
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

    <!-- Update-Benachrichtigung Banner -->
    <div id="update-banner" class="update-banner hidden">
        <div class="update-banner-content">
            <div class="update-info">
                <svg class="update-banner-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                </svg>
                <div class="update-details">
                    <h3>Neue Version verfügbar!</h3>
                    <p id="update-message">Eine neue Version von Pi Manager ist auf GitHub verfügbar.</p>
                    <div class="update-meta">
                        <span>Aktuell: <code id="current-version">...</code></span>
                        <span>Neueste: <code id="latest-version">...</code></span>
                    </div>
                </div>
            </div>
            <div class="update-actions">
                <button class="btn btn-success" id="update-now-btn">
                    <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                    </svg>
                    Jetzt aktualisieren
                </button>
                <button class="btn btn-secondary" id="dismiss-update-btn">
                    <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                    Später
                </button>
            </div>
        </div>
    </div>

    <main class="container">
        <!-- Pi Hardware-Informationen -->
        <div class="pi-hardware-section">
            <div class="card pi-info-card">
                <div class="card-header">
                    <h3 class="card-title">
                        <svg class="card-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                        </svg>
                        Pi Hardware-Identität
                    </h3>
                </div>
                <div class="card-content">
                    <div class="hardware-grid">
                        <div class="hardware-item">
                            <div class="hardware-label">Modell</div>
                            <div class="hardware-value" id="hw-model">Lädt...</div>
                        </div>
                        <div class="hardware-item">
                            <div class="hardware-label">Seriennummer</div>
                            <div class="hardware-value" id="hw-serial">Lädt...</div>
                        </div>
                        <div class="hardware-item">
                            <div class="hardware-label">MAC-Adresse</div>
                            <div class="hardware-value" id="hw-mac">Lädt...</div>
                        </div>
                        <div class="hardware-item">
                            <div class="hardware-label">Hostname</div>
                            <div class="hardware-value" id="hw-hostname">Lädt...</div>
                        </div>
                        <div class="hardware-item">
                            <div class="hardware-label">Revision</div>
                            <div class="hardware-value" id="hw-revision">Lädt...</div>
                        </div>
                        <div class="hardware-item">
                            <div class="hardware-label">Firmware</div>
                            <div class="hardware-value" id="hw-firmware">Lädt...</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

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
                            <span id="ram-usage">68%</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill warning" id="ram-bar" style="width: 68%"></div>
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
                        Netzwerk & Updates
                    </h3>
                </div>
                <div class="card-content">
                    <div class="system-info">
                        <div class="info-item">
                            <span class="info-label">IP-Adresse</span>
                            <span class="info-value" id="ip-address">192.168.0.202</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Branch</span>
                            <span class="info-value" id="git-branch">master</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Version</span>
                            <span class="info-value" id="git-version">...</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Update-Status</span>
                            <span class="info-value" id="update-status">Prüfe...</span>
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
                <span id="update-btn-text">Update von GitHub</span>
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
                Hardware Details
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
                    <div class="log-entry info">[INFO] Pi Manager mit Hardware-Info gestartet</div>
                    <div class="log-entry success">[SUCCESS] Hardware-Informationen verfügbar</div>
                    <div class="log-entry info">[INFO] Eindeutige Pi-Identifikation aktiv</div>
                    <div class="log-entry success">[SUCCESS] System bereit für Monitoring</div>
                </div>
            </div>
        </div>

        <!-- Hardware-Details Modal -->
        <div class="modal hidden" id="hardware-modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h2>Hardware-Details</h2>
                    <button class="modal-close" id="close-modal">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="hardware-details-grid">
                        <div class="hardware-section">
                            <h3>Grunddaten</h3>
                            <div class="hardware-item">
                                <span class="label">Modell:</span>
                                <span class="value" id="detail-model">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">Seriennummer:</span>
                                <span class="value" id="detail-serial">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">Revision:</span>
                                <span class="value" id="detail-revision">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">Hostname:</span>
                                <span class="value" id="detail-hostname">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">MAC-Adresse:</span>
                                <span class="value" id="detail-mac">...</span>
                            </div>
                        </div>
                        <div class="hardware-section">
                            <h3>Speicher</h3>
                            <div class="hardware-item">
                                <span class="label">RAM Gesamt:</span>
                                <span class="value" id="detail-ram-total">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">RAM Frei:</span>
                                <span class="value" id="detail-ram-free">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">RAM Verwendet:</span>
                                <span class="value" id="detail-ram-used">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">GPU-Speicher:</span>
                                <span class="value" id="detail-gpu-mem">...</span>
                            </div>
                        </div>
                        <div class="hardware-section">
                            <h3>System</h3>
                            <div class="hardware-item">
                                <span class="label">Betriebssystem:</span>
                                <span class="value" id="detail-os">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">Firmware:</span>
                                <span class="value" id="detail-firmware">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">CPU-Kerne:</span>
                                <span class="value" id="detail-cpu-cores">...</span>
                            </div>
                            <div class="hardware-item">
                                <span class="label">Uptime:</span>
                                <span class="value" id="detail-uptime">...</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <script src="js/app.js"></script>
</body>
</html>
EOF

# Erweiterte CSS für Hardware-Info
echo "🎨 Erweitere CSS für Hardware-Informationen..."
cat >> public/css/style.css << 'EOF'

/* Pi-Identität im Header */
.pi-identity {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    margin-right: 1rem;
}

.pi-model {
    font-weight: 600;
    font-size: 0.9rem;
    color: #2c3e50;
}

.pi-serial {
    font-size: 0.7rem;
    color: #7f8c8d;
    font-family: 'Courier New', monospace;
}

/* Hardware-Info-Sektion */
.pi-hardware-section {
    margin-bottom: 2rem;
}

.pi-info-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
}

.pi-info-card .card-header {
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
}

.pi-info-card .card-title {
    color: white;
}

.pi-info-card .card-icon {
    color: white;
}

.hardware-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
}

.hardware-item {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.hardware-label {
    font-size: 0.8rem;
    opacity: 0.8;
    font-weight: 500;
}

.hardware-value {
    font-size: 1rem;
    font-weight: 600;
    font-family: 'Courier New', monospace;
    word-break: break-all;
}

/* System-Info */
.system-info {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 0;
    border-bottom: 1px solid #eee;
}

.info-item:last-child {
    border-bottom: none;
}

.info-label {
    font-size: 0.9rem;
    font-weight: 500;
    color: #666;
}

.info-value {
    font-size: 0.9rem;
    font-weight: 600;
    color: #2c3e50;
    font-family: 'Courier New', monospace;
}

/* Hardware-Details Modal */
.modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
}

.modal.hidden {
    display: none;
}

.modal-content {
    background: white;
    border-radius: 12px;
    max-width: 800px;
    width: 90%;
    max-height: 90%;
    overflow-y: auto;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}

.modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 1px solid #eee;
}

.modal-header h2 {
    margin: 0;
    font-size: 1.5rem;
    color: #2c3e50;
}

.modal-close {
    background: none;
    border: none;
    font-size: 2rem;
    cursor: pointer;
    color: #999;
    padding: 0;
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: all 0.3s ease;
}

.modal-close:hover {
    background: #f8f9fa;
    color: #666;
}

.modal-body {
    padding: 1.5rem;
}

.hardware-details-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
}

.hardware-section {
    background: #f8f9fa;
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid #e9ecef;
}

.hardware-section h3 {
    margin: 0 0 1rem 0;
    color: #495057;
    font-size: 1.1rem;
    font-weight: 600;
    border-bottom: 2px solid #007bff;
    padding-bottom: 0.5rem;
}

.hardware-section .hardware-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid #dee2e6;
}

.hardware-section .hardware-item:last-child {
    border-bottom: none;
}

.hardware-section .label {
    font-size: 0.9rem;
    font-weight: 500;
    color: #6c757d;
}

.hardware-section .value {
    font-size: 0.9rem;
    font-weight: 600;
    color: #212529;
    font-family: 'Courier New', monospace;
    text-align: right;
    max-width: 60%;
    word-break: break-all;
}

/* Responsive Design */
@media (max-width: 768px) {
    .pi-identity {
        display: none;
    }
    
    .hardware-grid {
        grid-template-columns: 1fr;
    }
    
    .hardware-details-grid {
        grid-template-columns: 1fr;
    }
    
    .modal-content {
        width: 95%;
        margin: 2rem 0;
    }
    
    .hardware-section .hardware-item {
        flex-direction: column;
        align-items: flex-start;
        gap: 0.5rem;
    }
    
    .hardware-section .value {
        max-width: 100%;
        text-align: left;
    }
}

EOF

# Erweiterte JavaScript mit Hardware-Info
echo "⚙️ Erweitere JavaScript mit Hardware-Info..."
cat > public/js/app.js << 'EOF'
// Pi Manager Dashboard JavaScript mit Hardware-Info
document.addEventListener('DOMContentLoaded', function() {
    // Elemente
    const refreshBtn = document.getElementById('refresh-btn');
    const updateBtn = document.getElementById('update-btn');
    const updateBtnText = document.getElementById('update-btn-text');
    const restartServiceBtn = document.getElementById('restart-service-btn');
    const cleanBtn = document.getElementById('clean-btn');
    const infoBtn = document.getElementById('info-btn');
    const uptimeElement = document.getElementById('uptime');
    const cpuTempElement = document.getElementById('cpu-temp');
    const tempBarElement = document.getElementById('temp-bar');
    const logsElement = document.getElementById('logs');
    
    // Hardware-Elemente
    const piModelElement = document.getElementById('pi-model');
    const piSerialElement = document.getElementById('pi-serial');
    const hwModelElement = document.getElementById('hw-model');
    const hwSerialElement = document.getElementById('hw-serial');
    const hwMacElement = document.getElementById('hw-mac');
    const hwHostnameElement = document.getElementById('hw-hostname');
    const hwRevisionElement = document.getElementById('hw-revision');
    const hwFirmwareElement = document.getElementById('hw-firmware');
    const ramUsageElement = document.getElementById('ram-usage');
    const ramBarElement = document.getElementById('ram-bar');
    const ipAddressElement = document.getElementById('ip-address');
    
    // Update-Elemente
    const updateNotification = document.getElementById('update-notification');
    const updateBanner = document.getElementById('update-banner');
    const updateMessage = document.getElementById('update-message');
    const currentVersionElement = document.getElementById('current-version');
    const latestVersionElement = document.getElementById('latest-version');
    const updateNowBtn = document.getElementById('update-now-btn');
    const dismissUpdateBtn = document.getElementById('dismiss-update-btn');
    const gitBranchElement = document.getElementById('git-branch');
    const gitVersionElement = document.getElementById('git-version');
    const updateStatusElement = document.getElementById('update-status');
    
    // Modal-Elemente
    const hardwareModal = document.getElementById('hardware-modal');
    const closeModalBtn = document.getElementById('close-modal');

    // Hardware-Status
    let currentHardwareInfo = null;
    let currentUpdateInfo = null;

    // Event Listeners
    refreshBtn.addEventListener('click', function() {
        location.reload();
    });

    updateBtn.addEventListener('click', function() {
        if (currentUpdateInfo && currentUpdateInfo.updateAvailable) {
            performUpdate();
        } else {
            checkForUpdates();
        }
    });

    updateNowBtn.addEventListener('click', function() {
        performUpdate();
    });

    dismissUpdateBtn.addEventListener('click', function() {
        hideUpdateBanner();
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
        showHardwareModal();
    });

    closeModalBtn.addEventListener('click', function() {
        hideHardwareModal();
    });

    // Modal schließen bei Klick außerhalb
    hardwareModal.addEventListener('click', function(e) {
        if (e.target === hardwareModal) {
            hideHardwareModal();
        }
    });

    // Hardware-Funktionen
    function loadHardwareInfo() {
        fetch('/api/pi-hardware')
            .then(response => response.json())
            .then(data => {
                currentHardwareInfo = data;
                displayHardwareInfo(data);
                addLogEntry('success', 'Hardware-Informationen aktualisiert');
            })
            .catch(error => {
                console.error('Hardware-Info Fehler:', error);
                addLogEntry('error', 'Fehler beim Laden der Hardware-Informationen');
            });
    }

    function displayHardwareInfo(data) {
        // Header-Pi-Identität
        if (piModelElement && data.model) {
            const modelShort = data.model.replace('Raspberry Pi ', 'Pi ');
            piModelElement.textContent = modelShort;
        }
        
        if (piSerialElement && data.serialNumber) {
            piSerialElement.textContent = `SN: ${data.serialNumber.substring(-8)}`;
        }
        
        // Hardware-Grid
        if (hwModelElement) hwModelElement.textContent = data.model || 'Unbekannt';
        if (hwSerialElement) hwSerialElement.textContent = data.serialNumber || 'Unbekannt';
        if (hwMacElement) hwMacElement.textContent = data.macAddress || 'Unbekannt';
        if (hwHostnameElement) hwHostnameElement.textContent = data.hostname || 'Unbekannt';
        if (hwRevisionElement) hwRevisionElement.textContent = data.revision || 'Unbekannt';
        if (hwFirmwareElement) hwFirmwareElement.textContent = data.firmwareVersion || 'Unbekannt';
        
        // RAM-Nutzung
        if (data.memory && ramUsageElement && ramBarElement) {
            const totalGB = parseFloat(data.memory.total);
            const usedGB = parseFloat(data.memory.used);
            const percentage = Math.round((usedGB / totalGB) * 100);
            
            ramUsageElement.textContent = `${percentage}%`;
            ramBarElement.style.width = `${percentage}%`;
            
            // Farbe basierend auf Nutzung
            if (percentage > 80) {
                ramBarElement.className = 'progress-fill error';
            } else if (percentage > 60) {
                ramBarElement.className = 'progress-fill warning';
            } else {
                ramBarElement.className = 'progress-fill';
            }
        }
        
        // IP-Adresse
        if (ipAddressElement && data.network && data.network.interfaces) {
            const interfaces = Object.values(data.network.interfaces);
            if (interfaces.length > 0) {
                ipAddressElement.textContent = interfaces[0].ip || 'Unbekannt';
            }
        }
    }

    function showHardwareModal() {
        if (currentHardwareInfo) {
            populateHardwareModal(currentHardwareInfo);
        }
        hardwareModal.classList.remove('hidden');
    }

    function hideHardwareModal() {
        hardwareModal.classList.add('hidden');
    }

    function populateHardwareModal(data) {
        // Grunddaten
        document.getElementById('detail-model').textContent = data.model || 'Unbekannt';
        document.getElementById('detail-serial').textContent = data.serialNumber || 'Unbekannt';
        document.getElementById('detail-revision').textContent = data.revision || 'Unbekannt';
        document.getElementById('detail-hostname').textContent = data.hostname || 'Unbekannt';
        document.getElementById('detail-mac').textContent = data.macAddress || 'Unbekannt';
        
        // Speicher
        document.getElementById('detail-ram-total').textContent = data.memory?.total || 'Unbekannt';
        document.getElementById('detail-ram-free').textContent = data.memory?.free || 'Unbekannt';
        document.getElementById('detail-ram-used').textContent = data.memory?.used || 'Unbekannt';
        document.getElementById('detail-gpu-mem').textContent = data.gpuMemory || 'Unbekannt';
        
        // System
        document.getElementById('detail-os').textContent = data.os?.PRETTY_NAME || 'Unbekannt';
        document.getElementById('detail-firmware').textContent = data.firmwareVersion || 'Unbekannt';
        document.getElementById('detail-cpu-cores').textContent = data.cpu?.cores || 'Unbekannt';
        
        // Uptime formatieren
        if (data.system?.uptime) {
            const uptimeHours = Math.floor(data.system.uptime / 3600);
            const uptimeDays = Math.floor(uptimeHours / 24);
            const uptimeFormatted = uptimeDays > 0 ? `${uptimeDays}d ${uptimeHours % 24}h` : `${uptimeHours}h`;
            document.getElementById('detail-uptime').textContent = uptimeFormatted;
        } else {
            document.getElementById('detail-uptime').textContent = 'Unbekannt';
        }
    }

    // Update-Funktionen
    function checkForUpdates() {
        if (updateStatusElement) {
            updateStatusElement.innerHTML = '<span class="update-status-indicator checking">Prüfe...</span>';
        }

        fetch('/api/check-updates')
            .then(response => response.json())
            .then(data => {
                currentUpdateInfo = data;
                displayUpdateInfo(data);
                
                if (data.updateAvailable) {
                    showUpdateNotification(data);
                    addLogEntry('info', `Update verfügbar: ${data.latestCommitMessage}`);
                } else {
                    hideUpdateNotification();
                    addLogEntry('success', 'Pi Manager ist auf dem neuesten Stand');
                }
            })
            .catch(error => {
                console.error('Update-Check Fehler:', error);
                addLogEntry('error', 'Fehler beim Prüfen auf Updates');
                
                if (updateStatusElement) {
                    updateStatusElement.innerHTML = '<span class="update-status-indicator error">Fehler</span>';
                }
            });
    }

    function displayUpdateInfo(data) {
        // Update Git-Informationen
        if (gitBranchElement) {
            gitBranchElement.textContent = data.currentBranch || 'master';
        }
        
        if (gitVersionElement) {
            gitVersionElement.textContent = data.currentCommit || '...';
        }
        
        if (updateStatusElement) {
            if (data.updateAvailable) {
                updateStatusElement.innerHTML = '<span class="update-status-indicator update-available">Update verfügbar</span>';
            } else {
                updateStatusElement.innerHTML = '<span class="update-status-indicator up-to-date">Aktuell</span>';
            }
        }
        
        // Update Button-Text
        if (updateBtnText) {
            if (data.updateAvailable) {
                updateBtnText.textContent = 'Update installieren';
                updateBtn.classList.add('has-update');
            } else {
                updateBtnText.textContent = 'Nach Updates suchen';
                updateBtn.classList.remove('has-update');
            }
        }
        
        // Update Banner-Inhalte
        if (currentVersionElement) {
            currentVersionElement.textContent = data.currentCommit || '...';
        }
        
        if (latestVersionElement) {
            latestVersionElement.textContent = data.latestCommit || '...';
        }
        
        if (updateMessage) {
            updateMessage.textContent = data.latestCommitMessage || 'Eine neue Version ist verfügbar.';
        }
    }

    function showUpdateNotification(data) {
        if (updateNotification) {
            updateNotification.classList.remove('hidden');
        }
        
        if (updateBanner) {
            updateBanner.classList.remove('hidden');
        }
    }

    function hideUpdateNotification() {
        if (updateNotification) {
            updateNotification.classList.add('hidden');
        }
    }

    function hideUpdateBanner() {
        if (updateBanner) {
            updateBanner.classList.add('hidden');
        }
    }

    function performUpdate() {
        if (!confirm('Wirklich das Update von GitHub installieren? Pi Manager wird dabei neugestartet.')) {
            return;
        }

        addLogEntry('info', 'GitHub Update wird gestartet...');
        
        updateBtn.disabled = true;
        updateNowBtn.disabled = true;
        
        if (updateBtnText) {
            updateBtnText.textContent = 'Wird aktualisiert...';
        }

        fetch('/api/update-from-github', { method: 'POST' })
            .then(response => response.json())
            .then(data => {
                addLogEntry('success', data.message);
                addLogEntry('info', 'Pi Manager startet in 5 Sekunden neu...');
                
                // Countdown für Neustart
                let countdown = 5;
                const countdownInterval = setInterval(() => {
                    addLogEntry('info', `Neustart in ${countdown} Sekunden...`);
                    countdown--;
                    
                    if (countdown <= 0) {
                        clearInterval(countdownInterval);
                        addLogEntry('info', 'Neustart wird durchgeführt...');
                        
                        // Seite nach Neustart wieder laden
                        setTimeout(() => {
                            location.reload();
                        }, 3000);
                    }
                }, 1000);
            })
            .catch(error => {
                addLogEntry('error', 'Fehler beim Update: ' + error.message);
                updateBtn.disabled = false;
                updateNowBtn.disabled = false;
                
                if (updateBtnText) {
                    updateBtnText.textContent = 'Update fehlgeschlagen';
                }
            });
    }

    // Standard-Funktionen
    function addLogEntry(type, message) {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${type}`;
        logEntry.textContent = `[${timestamp}] [${type.toUpperCase()}] ${message}`;
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
    loadHardwareInfo();
    checkForUpdates();
    
    // Regelmäßige Updates
    setInterval(loadSystemInfo, 30000);
    setInterval(loadTemperature, 10000);
    setInterval(loadHardwareInfo, 60000); // Hardware-Info alle 60 Sekunden
    
    // Update-Check alle 5 Minuten
    setInterval(checkForUpdates, 5 * 60 * 1000);
    
    // Erste Prüfungen nach kurzer Verzögerung
    setTimeout(checkForUpdates, 5000);
    setTimeout(loadHardwareInfo, 2000);
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
    echo "🎉 Pi Manager Hardware-Info erfolgreich installiert!"
    echo "=================================================="
    echo ""
    echo "✅ Neue Hardware-Features:"
    echo "   - Eindeutige Pi-Identifikation im Header"
    echo "   - Hardware-Info-Karte mit Modell, Seriennummer, MAC"
    echo "   - Detaillierte Hardware-Informationen per Modal"
    echo "   - RAM-Nutzung in Echtzeit"
    echo "   - CPU-Kerne, Firmware, Betriebssystem-Info"
    echo "   - Netzwerk-Interfaces und IP-Adressen"
    echo "   - GPU-Speicher und Pi-spezifische Daten"
    echo ""
    echo "🔍 Hardware-Identifikation:"
    echo "   - Pi-Modell und Seriennummer im Header"
    echo "   - MAC-Adresse und Hostname"
    echo "   - Hardware-Revision und Firmware-Version"
    echo "   - Vollständige Systemdetails im Modal"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "📋 Features:"
    echo "   - Klick auf 'Hardware Details' für vollständige Informationen"
    echo "   - Automatische Hardware-Updates alle 60 Sekunden"
    echo "   - Eindeutige Pi-Identifikation für Multi-Pi-Umgebungen"
    echo "   - Responsive Design für mobile Geräte"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Fehler-Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi
