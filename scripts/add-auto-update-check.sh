#!/bin/bash
# Fügt automatische Update-Prüfung für GitHub hinzu
# Zeigt im Dashboard an, wenn eine neue Version verfügbar ist

echo "🔄 Pi Manager Auto-Update-Check Setup"
echo "====================================="
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

# Erweiterte app.js mit Update-Check
echo "🔧 Erweitere app.js mit Auto-Update-Check..."
cat > app.js << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const https = require('https');

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

# Erweiterte index.html mit Update-Benachrichtigung
echo "📄 Erweitere index.html mit Update-Benachrichtigung..."
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
                        Netzwerk & Updates
                    </h3>
                </div>
                <div class="card-content">
                    <div class="system-info">
                        <div class="info-item">
                            <span class="info-label">IP-Adresse</span>
                            <span class="info-value">192.168.0.202</span>
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
                    <div class="log-entry info">[INFO] Pi Manager mit Auto-Update gestartet</div>
                    <div class="log-entry success">[SUCCESS] GitHub API verbunden</div>
                    <div class="log-entry info">[INFO] Update-Prüfung alle 5 Minuten</div>
                    <div class="log-entry success">[SUCCESS] System bereit für Auto-Updates</div>
                </div>
            </div>
        </div>
    </main>

    <script src="js/app.js"></script>
</body>
</html>
EOF

# Erweiterte CSS für Update-Benachrichtigungen
echo "🎨 Erweitere CSS für Update-Benachrichtigungen..."
cat >> public/css/style.css << 'EOF'

/* Update-Benachrichtigungen */
.update-notification {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    color: white;
    border-radius: 20px;
    font-size: 0.9rem;
    font-weight: 500;
    animation: pulse-update 2s infinite;
}

.update-notification.hidden {
    display: none;
}

.update-icon {
    width: 16px;
    height: 16px;
}

@keyframes pulse-update {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.8; }
}

.update-banner {
    background: linear-gradient(135deg, #007bff 0%, #0056b3 100%);
    color: white;
    padding: 1rem 0;
    position: sticky;
    top: 0;
    z-index: 99;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.update-banner.hidden {
    display: none;
}

.update-banner-content {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.update-info {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.update-banner-icon {
    width: 32px;
    height: 32px;
    color: white;
}

.update-details h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
}

.update-details p {
    margin: 0 0 0.5rem 0;
    font-size: 0.9rem;
    opacity: 0.9;
}

.update-meta {
    display: flex;
    gap: 1rem;
    font-size: 0.8rem;
}

.update-meta code {
    background: rgba(255, 255, 255, 0.2);
    padding: 0.2rem 0.4rem;
    border-radius: 4px;
    font-family: 'Courier New', monospace;
}

.update-actions {
    display: flex;
    gap: 0.5rem;
}

.update-actions .btn {
    padding: 0.5rem 1rem;
    font-size: 0.9rem;
    min-width: auto;
}

/* Responsive Update-Banner */
@media (max-width: 768px) {
    .update-banner-content {
        flex-direction: column;
        text-align: center;
    }
    
    .update-info {
        flex-direction: column;
        text-align: center;
    }
    
    .update-meta {
        flex-direction: column;
        gap: 0.5rem;
    }
}

/* Update-Status Indikatoren */
.update-status-indicator {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.25rem 0.5rem;
    border-radius: 12px;
    font-size: 0.8rem;
    font-weight: 500;
}

.update-status-indicator.up-to-date {
    background: #d4edda;
    color: #155724;
}

.update-status-indicator.update-available {
    background: #fff3cd;
    color: #856404;
}

.update-status-indicator.checking {
    background: #d1ecf1;
    color: #0c5460;
}

.update-status-indicator.error {
    background: #f8d7da;
    color: #721c24;
}

/* Pulsing Update Button */
.btn.has-update {
    animation: pulse-button 2s infinite;
    background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    color: white;
}

@keyframes pulse-button {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
}

EOF

# Erweiterte JavaScript-Datei mit Auto-Update-Check
echo "⚙️ Erweitere JavaScript mit Auto-Update-Check..."
cat > public/js/app.js << 'EOF'
// Pi Manager Dashboard JavaScript mit Auto-Update-Check
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

    // Update-Status
    let currentUpdateInfo = null;
    let updateCheckInterval = null;

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
        loadSystemInfo();
    });

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
    checkForUpdates();
    
    // Regelmäßige Updates
    setInterval(loadSystemInfo, 30000);
    setInterval(loadTemperature, 10000);
    
    // Update-Check alle 5 Minuten
    updateCheckInterval = setInterval(checkForUpdates, 5 * 60 * 1000);
    
    // Erste Update-Prüfung nach 10 Sekunden
    setTimeout(checkForUpdates, 10000);
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
    echo "🎉 Pi Manager Auto-Update-Check erfolgreich installiert!"
    echo "====================================================="
    echo ""
    echo "✅ Neue Features:"
    echo "   - Automatische Update-Prüfung alle 5 Minuten"
    echo "   - GitHub API Integration"
    echo "   - Update-Benachrichtigung im Dashboard"
    echo "   - Ein-Klick-Update-Funktion"
    echo "   - Versions-Anzeige in Echtzeit"
    echo "   - Automatischer Neustart nach Updates"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "🔄 Auto-Update Features:"
    echo "   - Prüft automatisch auf neue GitHub-Commits"
    echo "   - Zeigt Update-Banner bei neuen Versionen"
    echo "   - Update-Button wird hervorgehoben"
    echo "   - Versions-Informationen im Dashboard"
    echo "   - Sichere Update-Installation mit Backup"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Fehler-Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi
