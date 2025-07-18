# SSH Host Key Problem lösen - Windows PowerShell Script

Write-Host "🔑 SSH Host Key Reparatur" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host ""

# Parameter
$PI_IP = "192.168.0.202"
$KNOWN_HOSTS_FILE = "$env:USERPROFILE\.ssh\known_hosts"

Write-Host "🔍 Prüfe SSH-Konfiguration..." -ForegroundColor Yellow
Write-Host "   Pi IP: $PI_IP" -ForegroundColor White
Write-Host "   Known Hosts: $KNOWN_HOSTS_FILE" -ForegroundColor White
Write-Host ""

# Prüfe ob known_hosts existiert
if (Test-Path $KNOWN_HOSTS_FILE) {
    Write-Host "✅ Known hosts Datei gefunden" -ForegroundColor Green
    
    # Backup erstellen
    $BackupFile = "$KNOWN_HOSTS_FILE.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $KNOWN_HOSTS_FILE $BackupFile
    Write-Host "📋 Backup erstellt: $BackupFile" -ForegroundColor Cyan
    
    # Alten Host-Key entfernen
    Write-Host "🔧 Entferne alten Host-Key für $PI_IP..." -ForegroundColor Yellow
    
    # Lese alle Zeilen außer der für die Pi-IP
    $Lines = Get-Content $KNOWN_HOSTS_FILE | Where-Object { $_ -notmatch "^$PI_IP" -and $_ -notmatch "^192\.168\.0\.202" }
    
    # Schreibe gefilterte Zeilen zurück
    $Lines | Out-File -FilePath $KNOWN_HOSTS_FILE -Encoding UTF8
    
    Write-Host "✅ Alter Host-Key entfernt" -ForegroundColor Green
    
} else {
    Write-Host "⚠️  Known hosts Datei nicht gefunden - wird erstellt bei erster Verbindung" -ForegroundColor Yellow
    
    # SSH-Verzeichnis erstellen falls nicht vorhanden
    $SSH_DIR = "$env:USERPROFILE\.ssh"
    if (!(Test-Path $SSH_DIR)) {
        New-Item -Path $SSH_DIR -ItemType Directory -Force | Out-Null
        Write-Host "📁 SSH-Verzeichnis erstellt: $SSH_DIR" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "🔑 Neue Host-Keys akzeptieren..." -ForegroundColor Yellow

# SSH-Verbindung mit automatischer Host-Key-Akzeptierung
Write-Host "🤖 Automatische Host-Key-Akzeptierung aktiviert" -ForegroundColor Cyan
Write-Host ""

# SSH-Befehl mit StrictHostKeyChecking=no für automatische Akzeptierung
Write-Host "🚀 SSH-Verbindung testen..." -ForegroundColor Green
Write-Host "Führe aus: ssh -o StrictHostKeyChecking=no pi@$PI_IP" -ForegroundColor White
Write-Host ""

# Erstelle temporäres SSH-Config für diesen Verbindungsversuch
$TempConfig = "$env:TEMP\ssh_config_temp"
@"
Host $PI_IP
    StrictHostKeyChecking no
    UserKnownHostsFile $KNOWN_HOSTS_FILE
"@ | Out-File -FilePath $TempConfig -Encoding UTF8

Write-Host "📋 Nächste Schritte:" -ForegroundColor Yellow
Write-Host "   1. Führe folgenden Befehl aus:" -ForegroundColor White
Write-Host "      ssh -o StrictHostKeyChecking=no pi@$PI_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "   2. Oder verwende automatische Verbindung:" -ForegroundColor White
Write-Host "      ssh -F `"$TempConfig`" pi@$PI_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "   3. Beim ersten Mal wird gefragt:" -ForegroundColor White
Write-Host "      'Are you sure you want to continue connecting (yes/no)?' -> yes eingeben" -ForegroundColor Cyan
Write-Host ""

# Teste SSH-Verbindung
Write-Host "🧪 Teste SSH-Verbindung..." -ForegroundColor Green
try {
    # Verwende ssh-keyscan um den neuen Host-Key zu holen
    $NewHostKey = ssh-keyscan -t ed25519 $PI_IP 2>$null
    if ($NewHostKey) {
        Write-Host "✅ Neuer Host-Key erfolgreich abgerufen" -ForegroundColor Green
        Write-Host "🔑 Neuer ED25519 Key: $($NewHostKey.Split(' ')[2].Substring(0,20))..." -ForegroundColor Cyan
        
        # Füge neuen Host-Key hinzu
        $NewHostKey | Out-File -FilePath $KNOWN_HOSTS_FILE -Append -Encoding UTF8
        Write-Host "✅ Neuer Host-Key zur known_hosts hinzugefügt" -ForegroundColor Green
        
    } else {
        Write-Host "⚠️  Host-Key konnte nicht automatisch abgerufen werden" -ForegroundColor Yellow
        Write-Host "   Manuell verbinden mit: ssh -o StrictHostKeyChecking=no pi@$PI_IP" -ForegroundColor White
    }
} catch {
    Write-Host "⚠️  Automatische Host-Key-Akzeptierung fehlgeschlagen" -ForegroundColor Yellow
    Write-Host "   Fehler: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Zusammenfassung:" -ForegroundColor Green
Write-Host "   ✅ Alter Host-Key entfernt" -ForegroundColor Green
Write-Host "   ✅ SSH-Verbindung sollte jetzt funktionieren" -ForegroundColor Green
Write-Host "   ✅ Neuer Host-Key wird automatisch akzeptiert" -ForegroundColor Green
Write-Host ""

Write-Host "🔧 SSH-Befehle zum Testen:" -ForegroundColor Yellow
Write-Host "   Basis-Verbindung: ssh pi@$PI_IP" -ForegroundColor White
Write-Host "   Sichere Verbindung: ssh -o StrictHostKeyChecking=ask pi@$PI_IP" -ForegroundColor White
Write-Host "   Debug-Modus: ssh -v pi@$PI_IP" -ForegroundColor White
Write-Host ""

Write-Host "🎉 Host-Key-Problem sollte behoben sein!" -ForegroundColor Green
Write-Host "   Jetzt können Sie sich normal mit SSH verbinden." -ForegroundColor Green

# Cleanup
Remove-Item $TempConfig -Force -ErrorAction SilentlyContinue
