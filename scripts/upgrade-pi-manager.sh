#!/bin/bash
# Pi Manager Upgrade - Professionelles System-Monitoring
# Erweitert den Pi Manager um CPU/RAM/Temperatur/Disk-Überwachung

echo "🚀 Pi Manager Upgrade - System-Monitoring"
echo "=========================================="

# Prüfe ob Pi Manager läuft
if ! systemctl is-active --quiet pi-manager; then
    echo "❌ Pi Manager läuft nicht. Bitte zuerst starten."
    exit 1
fi

# Stoppe Pi Manager für Upgrade
echo "🔄 Stoppe Pi Manager für Upgrade..."
sudo systemctl stop pi-manager

# Wechsle ins Pi Manager Directory
cd /home/pi/pi-manager

# Backup der aktuellen app.js
echo "📄 Erstelle Backup der aktuellen app.js..."
cp app.js app.js.backup

# Erweiterte app.js mit System-Monitoring erstellen
echo "⚙️ Erstelle erweiterte app.js mit System-Monitoring..."
cat > app.js << 'EOF'
const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const os = require('os');
const app = express();
const port = 3000;

// Hilfsfunktion für Async-Exec
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

// System-Informationen sammeln
async function getSystemInfo() {
    const info = {
        hostname: os.hostname(),
        uptime: process.uptime(),
        nodeVersion: process.version,
        platform: os.platform(),
        arch: os.arch(),
        timestamp: new Date().toLocaleString('de-DE')
    };

    try {
        // CPU-Informationen
        const cpuInfo = await execAsync("cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | sed 's/^ *//'");
        info.cpuModel = cpuInfo || 'Unknown';
        
        // CPU-Temperatur
        try {
            const temp = await execAsync("cat /sys/class/thermal/thermal_zone0/temp");
            info.cpuTemp = (parseInt(temp) / 1000).toFixed(1);
        } catch (e) {
            info.cpuTemp = 'N/A';
        }
        
        // CPU-Auslastung
        const loadAvg = os.loadavg();
        info.cpuLoad = {
            load1: loadAvg[0].toFixed(2),
            load5: loadAvg[1].toFixed(2),
            load15: loadAvg[2].toFixed(2)
        };
        
        // Memory-Informationen
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const usedMem = totalMem - freeMem;
        info.memory = {
            total: (totalMem / 1024 / 1024 / 1024).toFixed(2),
            used: (usedMem / 1024 / 1024 / 1024).toFixed(2),
            free: (freeMem / 1024 / 1024 / 1024).toFixed(2),
            percentage: ((usedMem / totalMem) * 100).toFixed(1)
        };
        
        // Disk-Usage
        const diskUsage = await execAsync("df -h / | awk 'NR==2 {print $2,$3,$4,$5}'");
        const diskParts = diskUsage.split(' ');
        info.disk = {
            total: diskParts[0],
            used: diskParts[1],
            free: diskParts[2],
            percentage: diskParts[3]
        };
        
        // Netzwerk-Informationen
        const networkInterfaces = os.networkInterfaces();
        info.network = {};
        for (const [interfaceName, addresses] of Object.entries(networkInterfaces)) {
            for (const addr of addresses) {
                if (addr.family === 'IPv4' && !addr.internal) {
                    info.network[interfaceName] = addr.address;
                }
            }
        }
        
        // Prozess-Informationen
        const processes = await execAsync("ps aux --sort=-%cpu | head -6 | tail -5");
        info.topProcesses = processes.split('\n').map(line => {
            const parts = line.trim().split(/\s+/);
            return {
                user: parts[0],
                pid: parts[1],
                cpu: parts[2],
                mem: parts[3],
                command: parts.slice(10).join(' ').substring(0, 30)
            };
        });
        
    } catch (error) {
        console.error('Error collecting system info:', error);
    }
    
    return info;
}

// Hauptroute mit System-Dashboard
app.get('/', async (req, res) => {
    try {
        const info = await getSystemInfo();
        
        res.send(`
            <!DOCTYPE html>
            <html lang="de">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Pi Manager - System Dashboard</title>
                <style>
                    * {
                        margin: 0;
                        padding: 0;
                        box-sizing: border-box;
                    }
                    
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        min-height: 100vh;
                        padding: 20px;
                    }
                    
                    .container {
                        max-width: 1200px;
                        margin: 0 auto;
                        background: rgba(255, 255, 255, 0.95);
                        border-radius: 20px;
                        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
                        overflow: hidden;
                    }
                    
                    .header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 30px;
                        text-align: center;
                    }
                    
                    .header h1 {
                        font-size: 2.5em;
                        margin-bottom: 10px;
                        font-weight: 300;
                    }
                    
                    .header .subtitle {
                        font-size: 1.2em;
                        opacity: 0.9;
                    }
                    
                    .dashboard {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                        gap: 20px;
                        padding: 30px;
                    }
                    
                    .card {
                        background: white;
                        border-radius: 15px;
                        padding: 25px;
                        box-shadow: 0 5px 15px rgba(0, 0, 0, 0.08);
                        border: 1px solid rgba(0, 0, 0, 0.05);
                        transition: transform 0.3s ease, box-shadow 0.3s ease;
                    }
                    
                    .card:hover {
                        transform: translateY(-5px);
                        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
                    }
                    
                    .card h3 {
                        color: #333;
                        margin-bottom: 20px;
                        font-size: 1.3em;
                        font-weight: 600;
                        display: flex;
                        align-items: center;
                    }
                    
                    .card h3::before {
                        content: '';
                        width: 4px;
                        height: 20px;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        margin-right: 10px;
                        border-radius: 2px;
                    }
                    
                    .metric {
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        margin-bottom: 15px;
                        padding: 10px 0;
                        border-bottom: 1px solid #f0f0f0;
                    }
                    
                    .metric:last-child {
                        border-bottom: none;
                        margin-bottom: 0;
                    }
                    
                    .metric-label {
                        color: #666;
                        font-weight: 500;
                    }
                    
                    .metric-value {
                        font-weight: 600;
                        color: #333;
                        font-size: 1.1em;
                    }
                    
                    .progress-bar {
                        width: 100%;
                        height: 8px;
                        background: #e0e0e0;
                        border-radius: 4px;
                        overflow: hidden;
                        margin-top: 5px;
                    }
                    
                    .progress-fill {
                        height: 100%;
                        background: linear-gradient(90deg, #4CAF50 0%, #8BC34A 50%, #FFC107 75%, #FF5722 100%);
                        border-radius: 4px;
                        transition: width 0.3s ease;
                    }
                    
                    .status-good { color: #4CAF50; }
                    .status-warning { color: #FF9800; }
                    .status-critical { color: #F44336; }
                    
                    .temp-display {
                        font-size: 2em;
                        font-weight: 300;
                        color: #667eea;
                        margin: 10px 0;
                    }
                    
                    .process-table {
                        width: 100%;
                        border-collapse: collapse;
                        margin-top: 15px;
                    }
                    
                    .process-table th,
                    .process-table td {
                        padding: 8px;
                        text-align: left;
                        border-bottom: 1px solid #f0f0f0;
                        font-size: 0.9em;
                    }
                    
                    .process-table th {
                        background: #f8f9fa;
                        font-weight: 600;
                        color: #333;
                    }
                    
                    .footer {
                        background: #f8f9fa;
                        padding: 20px;
                        text-align: center;
                        color: #666;
                        border-top: 1px solid #e0e0e0;
                    }
                    
                    .refresh-btn {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        border: none;
                        padding: 10px 20px;
                        border-radius: 25px;
                        cursor: pointer;
                        font-size: 1em;
                        font-weight: 500;
                        transition: all 0.3s ease;
                        margin-top: 20px;
                    }
                    
                    .refresh-btn:hover {
                        transform: translateY(-2px);
                        box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
                    }
                    
                    @media (max-width: 768px) {
                        .dashboard {
                            grid-template-columns: 1fr;
                            padding: 20px;
                        }
                        
                        .header h1 {
                            font-size: 2em;
                        }
                        
                        .card {
                            padding: 20px;
                        }
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🥧 Pi Manager</h1>
                        <div class="subtitle">System Dashboard - ${info.hostname}</div>
                    </div>
                    
                    <div class="dashboard">
                        <!-- System Info -->
                        <div class="card">
                            <h3>System Information</h3>
                            <div class="metric">
                                <span class="metric-label">Hostname</span>
                                <span class="metric-value">${info.hostname}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Uptime</span>
                                <span class="metric-value">${Math.floor(info.uptime / 86400)}d ${Math.floor((info.uptime % 86400) / 3600)}h ${Math.floor((info.uptime % 3600) / 60)}m</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Node.js</span>
                                <span class="metric-value">${info.nodeVersion}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Letzte Aktualisierung</span>
                                <span class="metric-value">${info.timestamp}</span>
                            </div>
                        </div>
                        
                        <!-- CPU -->
                        <div class="card">
                            <h3>CPU Information</h3>
                            <div class="metric">
                                <span class="metric-label">Prozessor</span>
                                <span class="metric-value">${info.cpuModel}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Temperatur</span>
                                <span class="metric-value temp-display ${info.cpuTemp > 70 ? 'status-critical' : info.cpuTemp > 60 ? 'status-warning' : 'status-good'}">${info.cpuTemp}°C</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Load Average</span>
                                <span class="metric-value">${info.cpuLoad.load1} | ${info.cpuLoad.load5} | ${info.cpuLoad.load15}</span>
                            </div>
                        </div>
                        
                        <!-- Memory -->
                        <div class="card">
                            <h3>Memory Usage</h3>
                            <div class="metric">
                                <span class="metric-label">Total RAM</span>
                                <span class="metric-value">${info.memory.total} GB</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Used</span>
                                <span class="metric-value">${info.memory.used} GB (${info.memory.percentage}%)</span>
                            </div>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${info.memory.percentage}%"></div>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Free</span>
                                <span class="metric-value">${info.memory.free} GB</span>
                            </div>
                        </div>
                        
                        <!-- Disk -->
                        <div class="card">
                            <h3>Disk Usage</h3>
                            <div class="metric">
                                <span class="metric-label">Total Space</span>
                                <span class="metric-value">${info.disk.total}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Used</span>
                                <span class="metric-value">${info.disk.used} (${info.disk.percentage})</span>
                            </div>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${info.disk.percentage}"></div>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Free</span>
                                <span class="metric-value">${info.disk.free}</span>
                            </div>
                        </div>
                        
                        <!-- Network -->
                        <div class="card">
                            <h3>Network Interfaces</h3>
                            ${Object.entries(info.network).map(([iface, ip]) => `
                                <div class="metric">
                                    <span class="metric-label">${iface}</span>
                                    <span class="metric-value">${ip}</span>
                                </div>
                            `).join('')}
                        </div>
                        
                        <!-- Top Processes -->
                        <div class="card">
                            <h3>Top Processes (CPU)</h3>
                            <table class="process-table">
                                <thead>
                                    <tr>
                                        <th>PID</th>
                                        <th>CPU%</th>
                                        <th>MEM%</th>
                                        <th>Command</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${info.topProcesses.map(proc => `
                                        <tr>
                                            <td>${proc.pid}</td>
                                            <td>${proc.cpu}%</td>
                                            <td>${proc.mem}%</td>
                                            <td>${proc.command}</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                    <div class="footer">
                        <button class="refresh-btn" onclick="location.reload()">🔄 Aktualisieren</button>
                        <p>Pi Manager v2.0 - Professionelles System-Monitoring</p>
                        <p>Login: admin / admin123 | SSH: pi@${info.network.eth0 || info.network.wlan0 || 'localhost'}</p>
                    </div>
                </div>
                
                <script>
                    // Auto-refresh alle 30 Sekunden
                    setTimeout(() => {
                        location.reload();
                    }, 30000);
                </script>
            </body>
            </html>
        `);
    } catch (error) {
        res.status(500).send('Error loading system information: ' + error.message);
    }
});

// API-Endpoint für System-Daten
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
        memory: process.memoryUsage(),
        hostname: os.hostname(),
        version: process.version
    });
});

// Server starten
app.listen(port, '0.0.0.0', () => {
    console.log(`🥧 Pi Manager v2.0 läuft auf Port ${port}`);
    console.log(`🌐 Dashboard: http://localhost:${port}`);
    console.log(`📊 API: http://localhost:${port}/api/system`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Pi Manager wird heruntergefahren...');
    process.exit(0);
});
EOF

# Rechte setzen
chmod +x app.js
chown pi:pi app.js

# Pi Manager neu starten
echo "🚀 Starte Pi Manager mit neuen Features..."
sudo systemctl start pi-manager

# Warten auf Start
sleep 3

# Status prüfen
if systemctl is-active --quiet pi-manager; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 Pi Manager v2.0 erfolgreich gestartet!"
    echo "======================================="
    echo ""
    echo "✅ Neue Features:"
    echo "   - CPU-Temperatur-Überwachung"
    echo "   - RAM-Usage mit Visualisierung"
    echo "   - Disk-Usage mit Grafiken"
    echo "   - Top-Prozesse-Anzeige"
    echo "   - Netzwerk-Interface-Übersicht"
    echo "   - Professionelles Dashboard-Design"
    echo "   - Auto-Refresh alle 30 Sekunden"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "📊 API: http://$PI_IP:3000/api/system"
    echo "🔧 Health Check: http://$PI_IP:3000/health"
    echo ""
    echo "📋 Login: admin / admin123"
    echo "🔗 SSH: pi@$PI_IP"
else
    echo "❌ Pi Manager konnte nicht gestartet werden"
    echo "📝 Logs prüfen:"
    sudo journalctl -u pi-manager -n 20 --no-pager
fi
EOF

chmod +x /home/pi/pi-manager/upgrade-pi-manager.sh
./upgrade-pi-manager.sh
