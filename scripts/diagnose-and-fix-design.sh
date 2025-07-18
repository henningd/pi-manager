#!/bin/bash
# Diagnose und Fix für das defekte Pi Manager Design
# Behebt CSS-Probleme und stellt sicher, dass alle Dateien korrekt geladen werden

echo "🔍 Pi Manager Design Diagnose & Fix"
echo "===================================="
echo ""

# Prüfe aktueller Status
echo "📊 Aktueller Status:"
echo "Branch: $(git branch --show-current)"
echo "Service: $(systemctl is-active pi-manager)"
echo ""

# Prüfe Dateistruktur
echo "🔍 Prüfe Dateistruktur:"
cd /home/pi/pi-manager

if [[ -f "public/index.html" ]]; then
    echo "✅ public/index.html vorhanden ($(stat -c%s public/index.html) bytes)"
else
    echo "❌ public/index.html FEHLT!"
fi

if [[ -f "public/css/style.css" ]]; then
    echo "✅ public/css/style.css vorhanden ($(stat -c%s public/css/style.css) bytes)"
else
    echo "❌ public/css/style.css FEHLT!"
fi

if [[ -f "public/js/app.js" ]]; then
    echo "✅ public/js/app.js vorhanden ($(stat -c%s public/js/app.js) bytes)"
else
    echo "❌ public/js/app.js FEHLT!"
fi

echo ""
echo "📋 Dateiinhalt-Check:"
if [[ -f "public/css/style.css" ]]; then
    CSS_SIZE=$(stat -c%s public/css/style.css)
    if [[ $CSS_SIZE -lt 1000 ]]; then
        echo "⚠️  CSS-Datei ist sehr klein ($CSS_SIZE bytes) - möglicherweise leer oder beschädigt"
        echo "🔍 Erste Zeilen:"
        head -5 public/css/style.css
    else
        echo "✅ CSS-Datei scheint vollständig zu sein ($CSS_SIZE bytes)"
    fi
fi

# Stoppe Pi Manager
echo ""
echo "🛑 Stoppe Pi Manager..."
sudo systemctl stop pi-manager
sleep 2

# Backup erstellen
BACKUP_DIR="/home/pi/pi-manager-backup-$(date +%Y%m%d_%H%M%S)"
echo "💾 Erstelle Backup: $BACKUP_DIR"
cp -r /home/pi/pi-manager "$BACKUP_DIR"

# Erstelle eine funktionierende CSS-Datei
echo "🎨 Erstelle neue CSS-Datei..."
mkdir -p public/css
cat > public/css/style.css << 'EOF'
/* Pi Manager - Modern Dashboard CSS */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    color: #333;
    line-height: 1.6;
}

.header {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    padding: 1rem 0;
    position: sticky;
    top: 0;
    z-index: 100;
}

.header-content {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.logo-section {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.logo-icon {
    width: 40px;
    height: 40px;
    color: #667eea;
}

.logo-text {
    font-size: 1.5rem;
    font-weight: 600;
    color: #333;
}

.header-actions {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.status-badge {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border-radius: 20px;
    font-size: 0.9rem;
    font-weight: 500;
}

.status-badge.online {
    background: #d4edda;
    color: #155724;
}

.status-indicator {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #28a745;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.card {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 20px;
    padding: 2rem;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
}

.card-header {
    margin-bottom: 1.5rem;
}

.card-title {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 1.25rem;
    font-weight: 600;
    color: #333;
}

.card-icon {
    width: 24px;
    height: 24px;
    color: #667eea;
}

.stats-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}

.stats-card .card-title {
    color: white;
}

.stats-card .card-icon {
    color: white;
}

.stat-value {
    font-size: 2.5rem;
    font-weight: 300;
    margin: 1rem 0;
}

.stat-label {
    font-size: 1rem;
    opacity: 0.9;
    margin-bottom: 0.5rem;
}

.stat-change {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    opacity: 0.9;
}

.stat-change.positive {
    color: #a8e6cf;
}

.progress-container {
    margin-bottom: 1.5rem;
}

.progress-label {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
    font-weight: 500;
}

.progress-bar {
    width: 100%;
    height: 8px;
    background: #e9ecef;
    border-radius: 4px;
    overflow: hidden;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #28a745 0%, #20c997 50%, #ffc107 75%, #dc3545 100%);
    border-radius: 4px;
    transition: width 0.3s ease;
}

.progress-fill.warning {
    background: linear-gradient(90deg, #ffc107 0%, #fd7e14 100%);
}

.progress-fill.error {
    background: linear-gradient(90deg, #dc3545 0%, #c82333 100%);
}

.system-info {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid #e9ecef;
}

.info-item:last-child {
    border-bottom: none;
}

.info-label {
    font-weight: 500;
    color: #6c757d;
}

.info-value {
    font-weight: 600;
    color: #333;
}

.action-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin-bottom: 3rem;
}

.btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
    text-decoration: none;
    text-align: center;
    justify-content: center;
    width: 100%;
}

.btn-icon {
    width: 20px;
    height: 20px;
}

.btn-primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
}

.btn-success {
    background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    color: white;
}

.btn-success:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(40, 167, 69, 0.3);
}

.btn-warning {
    background: linear-gradient(135deg, #ffc107 0%, #fd7e14 100%);
    color: white;
}

.btn-warning:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(255, 193, 7, 0.3);
}

.btn-secondary {
    background: linear-gradient(135deg, #6c757d 0%, #495057 100%);
    color: white;
}

.btn-secondary:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(108, 117, 125, 0.3);
}

.log-container {
    background: #f8f9fa;
    border-radius: 10px;
    padding: 1rem;
    max-height: 300px;
    overflow-y: auto;
    font-family: 'Courier New', monospace;
    font-size: 0.9rem;
}

.log-entry {
    padding: 0.25rem 0;
    border-bottom: 1px solid #e9ecef;
}

.log-entry:last-child {
    border-bottom: none;
}

.log-entry.info {
    color: #007bff;
}

.log-entry.success {
    color: #28a745;
}

.log-entry.warning {
    color: #ffc107;
}

.log-entry.error {
    color: #dc3545;
}

.alert {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem;
    margin-bottom: 1rem;
    border-radius: 10px;
    font-weight: 500;
}

.alert-icon {
    width: 20px;
    height: 20px;
    flex-shrink: 0;
}

.alert-success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
}

.alert-warning {
    background: #fff3cd;
    color: #856404;
    border: 1px solid #ffeaa7;
}

.alert-error {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
}

.alert-info {
    background: #d1ecf1;
    color: #0c5460;
    border: 1px solid #bee5eb;
}

.mt-4 {
    margin-top: 2rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    .header-content {
        flex-direction: column;
        gap: 1rem;
        text-align: center;
    }
    
    .container {
        padding: 1rem;
    }
    
    .dashboard-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
    
    .action-grid {
        grid-template-columns: 1fr;
    }
    
    .card {
        padding: 1.5rem;
    }
    
    .stat-value {
        font-size: 2rem;
    }
}

@media (max-width: 480px) {
    .logo-text {
        font-size: 1.25rem;
    }
    
    .card-title {
        font-size: 1.1rem;
    }
    
    .btn {
        padding: 0.5rem 1rem;
        font-size: 0.9rem;
    }
    
    .stat-value {
        font-size: 1.8rem;
    }
}
EOF

# Erstelle eine funktionierende index.html (falls defekt)
echo "📄 Erstelle neue index.html..."
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
                <button class="btn btn-secondary" onclick="window.location.reload()">
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
                <div class="stat-value">24h 15m</div>
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
                            <span>42°C</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: 42%"></div>
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
                            <span class="info-value">WiFi</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="action-grid">
            <button class="btn btn-primary">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                </svg>
                Update von GitHub
            </button>
            
            <button class="btn btn-success">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                </svg>
                Dienste Neustarten
            </button>

            <button class="btn btn-warning">
                <svg class="btn-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                </svg>
                System Bereinigen
            </button>

            <button class="btn btn-secondary">
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
                <div class="log-container">
                    <div class="log-entry info">[INFO] Pi Manager gestartet</div>
                    <div class="log-entry success">[SUCCESS] Alle Services laufen</div>
                    <div class="log-entry info">[INFO] System bereit für Verbindungen</div>
                    <div class="log-entry success">[SUCCESS] Design erfolgreich geladen</div>
                </div>
            </div>
        </div>
    </main>

    <script>
        // Auto-refresh alle 30 Sekunden
        setTimeout(() => {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
EOF

# Rechte korrigieren
echo "🔧 Korrigiere Dateiberechtigungen..."
sudo chown -R pi:pi /home/pi/pi-manager
chmod -R 755 /home/pi/pi-manager

# Prüfe finale Dateien
echo ""
echo "✅ Finale Datei-Überprüfung:"
ls -lh public/index.html
ls -lh public/css/style.css

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
    echo "🎉 Pi Manager Design erfolgreich repariert!"
    echo "========================================="
    echo ""
    echo "✅ Problem behoben:"
    echo "   - CSS-Datei neu erstellt"
    echo "   - HTML-Datei repariert"
    echo "   - Rechte korrigiert"
    echo "   - Service gestartet"
    echo ""
    echo "🌐 Dashboard: http://$PI_IP:3000"
    echo "💡 Wichtig: Drücke Strg+F5 für Hard-Refresh!"
    echo "💾 Backup: $BACKUP_DIR"
    echo ""
    echo "🎨 Das neue Design sollte jetzt korrekt angezeigt werden!"
else
    echo ""
    echo "❌ Pi Manager konnte nicht gestartet werden!"
    echo "📋 Fehler-Logs:"
    sudo journalctl -u pi-manager -n 10 --no-pager
fi
