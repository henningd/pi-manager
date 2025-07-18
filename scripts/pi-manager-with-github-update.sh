#!/bin/bash
# Pi Manager v2.1 mit GitHub Auto-Update Funktion

echo "🚀 Pi Manager v2.1 mit GitHub Auto-Update"
echo "========================================"

# Ins Pi Manager Directory wechseln
cd /home/pi/pi-manager

# Pi Manager stoppen
echo "🔄 Stoppe Pi Manager..."
sudo systemctl stop pi-manager

# Backup erstellen
echo "📄 Erstelle Backup..."
cp app.js app.js.backup.$(date +%Y%m%d_%H%M%S)

# Erweiterte app.js mit GitHub-Update-Funktion erstellen
echo "⚡ Erstelle erweiterte app.js mit GitHub-Update..."
cat > app.js << 'APPJS'
const express = require('express');
const { exec } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');
const app = express();
const port = 3000;

// Middleware für JSON-Parsing
app.use(express.json());

function execAsync(command) {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

async function getSystemInfo() {
    const info = {
        hostname: os.hostname(),
        uptime: process.uptime(),
        nodeVersion: process.version,
        timestamp: new Date().toLocaleString('de-DE'),
        version: '2.1'
    };

    try {
        // CPU-Temperatur
        const temp = await execAsync("cat /sys/class/thermal/thermal_zone0/temp");
        info.cpuTemp = (parseInt(temp) / 1000).toFixed(1);
        
        // CPU-Auslastung
        const loadAvg = os.loadavg();
        info.cpuLoad = loadAvg[0].toFixed(2);
        
        // Memory
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const usedMem = totalMem - freeMem;
        info.memory = {
            total: (totalMem / 1024 / 1024 / 1024).toFixed(2),
            used: (usedMem / 1024 / 1024 / 1024).toFixed(2),
            percentage: ((usedMem / totalMem) * 100).toFixed(1)
        };
        
        // Disk
        const diskUsage = await execAsync("df -h / | awk 'NR==2 {print $2,$3,$4,$5}'");
        const diskParts = diskUsage.split(' ');
        info.disk = {
            total: diskParts[0],
            used: diskParts[1],
            percentage: diskParts[3]
        };
        
        // IP-Adresse
        const ip = await execAsync("hostname -I | awk '{print $1}'");
        info.ip = ip;
        
        // Git-Status (falls verfügbar)
        try {
            const gitStatus = await execAsync("git status --porcelain");
            const gitBranch = await execAsync("git rev-parse --abbrev-ref HEAD");
            const gitCommit = await execAsync("git rev-parse --short HEAD");
            info.git = {
                branch: gitBranch,
                commit: gitCommit,
                hasChanges: gitStatus.length > 0
            };
        } catch (e) {
            info.git = { available: false };
        }
        
    } catch (error) {
        console.error('Error:', error);
        info.cpuTemp = 'N/A';
        info.cpuLoad = 'N/A';
        info.ip = 'N/A';
    }
    
    return info;
}

// GitHub Update-Funktion
async function performGitHubUpdate() {
    try {
        console.log('🔄 Starting GitHub update...');
        
        // Git pull
        await execAsync("git pull origin main");
        console.log('✅ Git pull completed');
        
        // NPM install falls package.json geändert wurde
        if (fs.existsSync('package.json')) {
            await execAsync("npm install");
            console.log('✅ NPM install completed');
        }
        
        // Service neu starten
        console.log('🔄 Restarting Pi Manager service...');
        await execAsync("sudo systemctl restart pi-manager");
        
        return { success: true, message: 'Update completed successfully' };
    } catch (error) {
        console.error('❌ Update failed:', error);
        return { success: false, message: error.message };
    }
}

// Hauptroute
app.get('/', async (req, res) => {
    try {
        const info = await getSystemInfo();
        
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Pi Manager v2.1</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { font-family: Arial, sans-serif; margin: 0; background: #f5f5f5; }
                    .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; text-align: center; }
                    .header h1 { margin: 0; font-size: 2.5em; }
                    .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                    .card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    .card h3 { color: #333; margin-bottom: 15px; font-size: 1.3em; }
                    .metric { display: flex; justify-content: space-between; margin-bottom: 10px; padding: 10px 0; border-bottom: 1px solid #eee; }
                    .metric-label { color: #666; }
                    .metric-value { font-weight: bold; color: #333; }
                    .progress-bar { width: 100%; height: 20px; background: #e0e0e0; border-radius: 10px; overflow: hidden; margin-top: 10px; }
                    .progress-fill { height: 100%; background: linear-gradient(90deg, #4CAF50 0%, #FFC107 70%, #FF5722 100%); transition: width 0.3s ease; }
                    .temp-display { font-size: 2em; color: ${info.cpuTemp > 70 ? '#FF5722' : info.cpuTemp > 60 ? '#FF9800' : '#4CAF50'}; }
                    .btn { border: none; padding: 12px 24px; border-radius: 5px; cursor: pointer; margin: 5px; font-size: 14px; font-weight: bold; transition: all 0.3s ease; }
                    .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.2); }
                    .btn-primary { background: #667eea; color: white; }
                    .btn-success { background: #4CAF50; color: white; }
                    .btn-warning { background: #FF9800; color: white; }
                    .btn-danger { background: #FF5722; color: white; }
                    .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
                    .update-section { background: #f8f9fa; padding: 20px; border-radius: 10px; margin-top: 20px; border: 2px solid #e9ecef; }
                    .update-section h3 { color: #495057; margin-bottom: 15px; }
                    .git-info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin-bottom: 15px; border-left: 4px solid #0066cc; }
                    .status-indicator { width: 12px; height: 12px; border-radius: 50%; display: inline-block; margin-right: 8px; }
                    .status-online { background: #4CAF50; }
                    .status-updating { background: #FF9800; animation: pulse 1s infinite; }
                    .status-offline { background: #FF5722; }
                    .footer { text-align: center; margin-top: 30px; color: #666; }
                    .notification { position: fixed; top: 20px; right: 20px; padding: 15px 20px; border-radius: 5px; color: white; font-weight: bold; z-index: 1000; transform: translateX(100%); transition: transform 0.3s ease; }
                    .notification.show { transform: translateX(0); }
                    .notification.success { background: #4CAF50; }
                    .notification.error { background: #FF5722; }
                    .notification.info { background: #2196F3; }
                    .reconnect-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); color: white; display: none; justify-content: center; align-items: center; z-index: 2000; }
                    .reconnect-content { text-align: center; padding: 40px; background: rgba(255,255,255,0.1); border-radius: 10px; backdrop-filter: blur(10px); }
                    .spinner { width: 50px; height: 50px; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; animation: spin 1s linear infinite; margin: 20px auto; }
                    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
                    @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
                    @media (max-width: 768px) { .dashboard { grid-template-columns: 1fr; } }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🥧 Pi Manager v2.1</h1>
                        <p>System Dashboard - ${info.hostname}</p>
                        <p><span class="status-indicator status-online"></span>Online - Auto-Update Ready</p>
                    </div>
                    
                    <div class="dashboard">
                        <div class="card">
                            <h3>📊 System Info</h3>
                            <div class="metric">
                                <span class="metric-label">Hostname</span>
                                <span class="metric-value">${info.hostname}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">IP-Adresse</span>
                                <span class="metric-value">${info.ip}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Uptime</span>
                                <span class="metric-value">${Math.floor(info.uptime / 86400)}d ${Math.floor((info.uptime % 86400) / 3600)}h ${Math.floor((info.uptime % 3600) / 60)}m</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Version</span>
                                <span class="metric-value">v${info.version}</span>
                            </div>
                        </div>
                        
                        <div class="card">
                            <h3>🌡️ CPU Status</h3>
                            <div class="metric">
                                <span class="metric-label">Temperatur</span>
                                <span class="metric-value temp-display">${info.cpuTemp}°C</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Load Average</span>
                                <span class="metric-value">${info.cpuLoad}</span>
                            </div>
                        </div>
                        
                        <div class="card">
                            <h3>💾 Memory</h3>
                            <div class="metric">
                                <span class="metric-label">Total</span>
                                <span class="metric-value">${info.memory.total} GB</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Used</span>
                                <span class="metric-value">${info.memory.used} GB (${info.memory.percentage}%)</span>
                            </div>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${info.memory.percentage}%"></div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <h3>💽 Disk Usage</h3>
                            <div class="metric">
                                <span class="metric-label">Total</span>
                                <span class="metric-value">${info.disk.total}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Used</span>
                                <span class="metric-value">${info.disk.used} (${info.disk.percentage})</span>
                            </div>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${info.disk.percentage}"></div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="update-section">
                        <h3>🔄 GitHub Auto-Update</h3>
                        ${info.git.available !== false ? `
                            <div class="git-info">
                                <strong>Git Status:</strong><br>
                                Branch: ${info.git.branch}<br>
                                Commit: ${info.git.commit}<br>
                                Changes: ${info.git.hasChanges ? 'Yes' : 'No'}
                            </div>
                        ` : ''}
                        
                        <p>Klicken Sie auf "Update von GitHub", um die neueste Version zu laden und das System automatisch neu zu starten.</p>
                        
                        <button id="updateBtn" class="btn btn-warning" onclick="performUpdate()">
                            🔄 Update von GitHub
                        </button>
                        
                        <button class="btn btn-success" onclick="location.reload()">
                            🔄 Seite aktualisieren
                        </button>
                        
                        <button class="btn btn-danger" onclick="restartSystem()">
                            🔄 System neustarten
                        </button>
                    </div>
                    
                    <div class="footer">
                        <p>Pi Manager v2.1 - Last Update: ${info.timestamp}</p>
                        <p>Login: admin / admin123</p>
                    </div>
                </div>
                
                <!-- Notification -->
                <div id="notification" class="notification"></div>
                
                <!-- Reconnect Overlay -->
                <div id="reconnectOverlay" class="reconnect-overlay">
                    <div class="reconnect-content">
                        <div class="spinner"></div>
                        <h2>System wird aktualisiert...</h2>
                        <p>Bitte warten Sie, während das System von GitHub aktualisiert wird.</p>
                        <p>Die Seite wird automatisch neu geladen, sobald das Update abgeschlossen ist.</p>
                        <div id="reconnectStatus">Status: Aktualisierung läuft...</div>
                    </div>
                </div>
                
                <script>
                    let reconnectAttempts = 0;
                    const maxReconnectAttempts = 30;
                    
                    function showNotification(message, type = 'info') {
                        const notification = document.getElementById('notification');
                        notification.textContent = message;
                        notification.className = 'notification ' + type;
                        notification.classList.add('show');
                        
                        setTimeout(() => {
                            notification.classList.remove('show');
                        }, 5000);
                    }
                    
                    function showReconnectOverlay() {
                        document.getElementById('reconnectOverlay').style.display = 'flex';
                    }
                    
                    function hideReconnectOverlay() {
                        document.getElementById('reconnectOverlay').style.display = 'none';
                    }
                    
                    async function performUpdate() {
                        const updateBtn = document.getElementById('updateBtn');
                        updateBtn.disabled = true;
                        updateBtn.innerHTML = '🔄 Aktualisierung läuft...';
                        
                        showNotification('GitHub Update wird gestartet...', 'info');
                        
                        try {
                            const response = await fetch('/api/update', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' }
                            });
                            
                            const result = await response.json();
                            
                            if (result.success) {
                                showNotification('Update erfolgreich! System wird neu gestartet...', 'success');
                                showReconnectOverlay();
                                
                                // Warte 3 Sekunden, dann versuche Wiederverbindung
                                setTimeout(() => {
                                    attemptReconnect();
                                }, 3000);
                                
                            } else {
                                showNotification('Update fehlgeschlagen: ' + result.message, 'error');
                                updateBtn.disabled = false;
                                updateBtn.innerHTML = '🔄 Update von GitHub';
                            }
                        } catch (error) {
                            showNotification('Update-Fehler: ' + error.message, 'error');
                            updateBtn.disabled = false;
                            updateBtn.innerHTML = '🔄 Update von GitHub';
                        }
                    }
                    
                    async function attemptReconnect() {
                        const statusElement = document.getElementById('reconnectStatus');
                        statusElement.textContent = 'Status: Versuche Wiederverbindung... (Versuch ' + (reconnectAttempts + 1) + '/' + maxReconnectAttempts + ')';
                        
                        try {
                            const response = await fetch('/health');
                            if (response.ok) {
                                statusElement.textContent = 'Status: Verbindung wiederhergestellt! Seite wird neu geladen...';
                                setTimeout(() => {
                                    location.reload();
                                }, 2000);
                                return;
                            }
                        } catch (error) {
                            // Verbindung noch nicht verfügbar
                        }
                        
                        reconnectAttempts++;
                        
                        if (reconnectAttempts < maxReconnectAttempts) {
                            setTimeout(() => {
                                attemptReconnect();
                            }, 2000);
                        } else {
                            statusElement.textContent = 'Status: Wiederverbindung fehlgeschlagen. Bitte Seite manuell neu laden.';
                        }
                    }
                    
                    async function restartSystem() {
                        if (confirm('System wirklich neustarten?')) {
                            showNotification('System wird neu gestartet...', 'info');
                            await fetch('/api/restart', { method: 'POST' });
                            showReconnectOverlay();
                            setTimeout(() => attemptReconnect(), 5000);
                        }
                    }
                    
                    // Auto-refresh alle 60 Sekunden (nur wenn nicht updating)
                    setInterval(() => {
                        if (!document.getElementById('reconnectOverlay').style.display || document.getElementById('reconnectOverlay').style.display === 'none') {
                            location.reload();
                        }
                    }, 60000);
                </script>
            </body>
            </html>
        `);
    } catch (error) {
        res.status(500).send('Error: ' + error.message);
    }
});

// API-Endpoint für GitHub Update
app.post('/api/update', async (req, res) => {
    try {
        console.log('🔄 GitHub Update requested');
        
        // Update in separatem Prozess ausführen, damit der Response noch gesendet werden kann
        setTimeout(async () => {
            await performGitHubUpdate();
        }, 1000);
        
        res.json({ success: true, message: 'Update wird ausgeführt...' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// API-Endpoint für System-Neustart
app.post('/api/restart', async (req, res) => {
    try {
        console.log('🔄 System restart requested');
        
        setTimeout(async () => {
            await execAsync('sudo reboot');
        }, 1000);
        
        res.json({ success: true, message: 'System wird neu gestartet...' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// System-Info API
app.get('/api/system', async (req, res) => {
    try {
        const info = await getSystemInfo();
        res.json(info);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health Check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        hostname: os.hostname(),
        version: '2.1'
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`🥧 Pi Manager v2.1 läuft auf Port ${port}`);
    console.log(`🌐 Dashboard: http://localhost:${port}`);
    console.log(`🔄 GitHub Auto-Update bereit`);
});
APPJS

# Berechtigungen setzen
chmod +x app.js
chown pi:pi app.js

# Pi Manager neu starten
echo "🚀 Starte Pi Manager v2.1..."
sudo systemctl start pi-manager

sleep 3

if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager v2.1 erfolgreich gestartet!"
    echo "======================================="
    echo ""
    echo "✅ Neue Features:"
    echo "   - 🔄 GitHub Auto-Update Button"
    echo "   - 🌐 Automatische Wiederverbindung"
    echo "   - 📊 Erweiterte System-Überwachung"
    echo "   - 🔄 System-Neustart Button"
    echo "   - 📱 Responsive Design"
    echo "   - 🔔 Benachrichtigungen"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "📊 API: http://$PI_IP:3000/api/system"
    echo "🔄 Update: http://$PI_IP:3000/api/update"
    echo "🔧 Health: http://$PI_IP:3000/health"
    echo ""
    echo "🎯 GitHub Auto-Update ist bereit!"
    echo "   Klicken Sie auf 'Update von GitHub' für automatische Updates"
else
    echo "❌ Pi Manager konnte nicht gestartet werden"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi
