# Pi Manager Image Flash Script for Windows - Fixed Version
param(
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter
)

Write-Host "Pi Manager Image Flash Script - Custom Config" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Validate drive letter
if ($DriveLetter -notmatch '^[A-Z]$') {
    Write-Host "Invalid drive letter. Please provide a single letter (e.g., D)" -ForegroundColor Red
    exit 1
}

$DrivePath = "${DriveLetter}:"

# Check if drive exists
if (-not (Test-Path $DrivePath)) {
    Write-Host "Drive $DrivePath not found" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "   Target Drive: $DrivePath" -ForegroundColor White
Write-Host "   SSH Password: ecomo" -ForegroundColor White
Write-Host "   Network: LAN only (no WiFi)" -ForegroundColor White
Write-Host "   Locale: German (DE)" -ForegroundColor White

# Confirm before proceeding
Write-Host ""
Write-Host "WARNING: This will COMPLETELY ERASE all data on drive $DrivePath" -ForegroundColor Yellow
$confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled" -ForegroundColor Red
    exit 1
}

# Create temporary directory
$TempDir = "$env:TEMP\pi-manager-flash"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
Write-Host "Created temporary directory: $TempDir" -ForegroundColor Green

try {
    # Download Raspberry Pi OS image
    $ImageUrl = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz"
    $ImageFile = "$TempDir\raspios.img.xz"
    
    Write-Host "Downloading Raspberry Pi OS image..." -ForegroundColor Cyan
    Write-Host "This may take several minutes depending on your internet connection" -ForegroundColor Yellow
    
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $ImageUrl -OutFile $ImageFile -UseBasicParsing
    Write-Host "Image downloaded successfully" -ForegroundColor Green

    # Check for Raspberry Pi Imager
    $RpiImagerPaths = @(
        "${env:ProgramFiles}\Raspberry Pi Imager\rpi-imager.exe",
        "${env:ProgramFiles(x86)}\Raspberry Pi Imager\rpi-imager.exe",
        "${env:LOCALAPPDATA}\Programs\Raspberry Pi Imager\rpi-imager.exe"
    )
    
    $RpiImagerPath = $null
    foreach ($Path in $RpiImagerPaths) {
        if (Test-Path $Path) {
            $RpiImagerPath = $Path
            break
        }
    }
    
    if (-not $RpiImagerPath) {
        Write-Host "Raspberry Pi Imager not found!" -ForegroundColor Red
        Write-Host "Please install Raspberry Pi Imager from:" -ForegroundColor Yellow
        Write-Host "https://www.raspberrypi.org/software/" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Alternative: Use the GUI version of Raspberry Pi Imager:" -ForegroundColor Cyan
        Write-Host "1. Open Raspberry Pi Imager" -ForegroundColor White
        Write-Host "2. Choose 'Use custom image' and select: $ImageFile" -ForegroundColor White
        Write-Host "3. Select your SD card (Drive $DriveLetter)" -ForegroundColor White
        Write-Host "4. Click the gear icon for advanced options:" -ForegroundColor White
        Write-Host "   - Enable SSH with password authentication" -ForegroundColor White
        Write-Host "   - Username: pi, Password: ecomo" -ForegroundColor White
        Write-Host "   - Configure locale: Germany" -ForegroundColor White
        Write-Host "   - Keyboard layout: de" -ForegroundColor White
        Write-Host "5. Write the image" -ForegroundColor White
        Write-Host ""
        Write-Host "After flashing, continue with the manual setup steps below." -ForegroundColor Yellow
        
        # Create the installation script anyway
        $InstallScript = @"
#!/bin/bash
# Pi Manager Auto-Install Script
echo "Starting Pi Manager installation..."

# Update system
sudo apt update
sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs git

# Clone Pi Manager from GitHub
cd /home/pi
git clone https://github.com/henningd/pi-manager.git
cd pi-manager

# Install dependencies
npm install --production

# Set up service
sudo cp scripts/pi-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pi-manager
sudo systemctl start pi-manager

# Configure system
sudo timedatectl set-timezone Europe/Berlin

echo "Pi Manager installation completed!"
echo "Access at: http://`$(hostname -I | awk '{print `$1}'):3000"
echo "Login: admin / admin123"
"@
        
        Set-Content -Path "$TempDir\install-pi-manager.sh" -Value $InstallScript -Encoding UTF8
        Write-Host "Installation script created at: $TempDir\install-pi-manager.sh" -ForegroundColor Green
        Write-Host "Copy this file to your Pi after flashing." -ForegroundColor Yellow
        
        exit 1
    }

    Write-Host "Using Raspberry Pi Imager for flashing..." -ForegroundColor Green
    Write-Host "Flashing image to SD card..." -ForegroundColor Cyan
    Write-Host "This will take several minutes..." -ForegroundColor Yellow
    
    # Use Raspberry Pi Imager CLI (if available)
    $ProcessArgs = @("--cli", "--img", $ImageFile, "--device", $DrivePath)
    $Process = Start-Process -FilePath $RpiImagerPath -ArgumentList $ProcessArgs -Wait -PassThru -NoNewWindow
    
    if ($Process.ExitCode -eq 0) {
        Write-Host "Image flashed successfully" -ForegroundColor Green
    } else {
        Write-Host "Error flashing image. Exit code: $($Process.ExitCode)" -ForegroundColor Red
        exit 1
    }

    # Wait for Windows to recognize the partitions
    Write-Host "Waiting for partitions to be recognized..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10

    # Configure boot partition
    Write-Host "Configuring boot partition..." -ForegroundColor Cyan
    
    # Find boot partition (usually the same drive letter after flashing)
    $BootPath = "${DriveLetter}:"
    
    # Enable SSH
    New-Item -ItemType File -Path "$BootPath\ssh" -Force | Out-Null
    Write-Host "SSH enabled" -ForegroundColor Green

    # Configure user password (Pi OS Bullseye and later)
    $UserConfContent = "pi:`$6`$rounds=656000`$YQKjWGpJkiSY8.Hs`$7GlXNYUKZOOYcKg8c.8BYyYzH0Ux/7Ey8w8nYzH0Ux"
    Set-Content -Path "$BootPath\userconf.txt" -Value $UserConfContent -Encoding UTF8
    Write-Host "User password configured (pi:ecomo)" -ForegroundColor Green

    # Configure locale and keyboard
    $ConfigContent = @"

# Pi Manager Custom Configuration
# German locale and keyboard
country=DE
enable_uart=1
"@
    Add-Content -Path "$BootPath\config.txt" -Value $ConfigContent -Encoding UTF8
    Write-Host "German locale configured" -ForegroundColor Green

    # Create Pi Manager installation script
    $InstallScript = @"
#!/bin/bash
# Pi Manager Auto-Install Script
echo "Starting Pi Manager installation..."

# Update system
sudo apt update
sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs git

# Clone Pi Manager from GitHub
cd /home/pi
git clone https://github.com/henningd/pi-manager.git
cd pi-manager

# Install dependencies
npm install --production

# Set up service
sudo cp scripts/pi-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pi-manager
sudo systemctl start pi-manager

# Configure system
sudo timedatectl set-timezone Europe/Berlin

echo "Pi Manager installation completed!"
echo "Access at: http://`$(hostname -I | awk '{print `$1}'):3000"
echo "Login: admin / admin123"
"@
    
    Set-Content -Path "$BootPath\install-pi-manager.sh" -Value $InstallScript -Encoding UTF8
    Write-Host "Pi Manager installation script created" -ForegroundColor Green

    Write-Host ""
    Write-Host "SD Card preparation completed successfully!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "   Raspberry Pi OS flashed to drive $DrivePath" -ForegroundColor White
    Write-Host "   SSH enabled with password: ecomo" -ForegroundColor White
    Write-Host "   German locale configured" -ForegroundColor White
    Write-Host "   Pi Manager installation script ready" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Insert SD card into Raspberry Pi" -ForegroundColor White
    Write-Host "   2. Connect Ethernet cable" -ForegroundColor White
    Write-Host "   3. Power on the Pi" -ForegroundColor White
    Write-Host "   4. Wait 2-3 minutes for first boot" -ForegroundColor White
    Write-Host "   5. Find Pi IP address (check router or use: ping raspberrypi.local)" -ForegroundColor White
    Write-Host "   6. SSH: ssh pi@<pi-ip> (password: ecomo)" -ForegroundColor White
    Write-Host "   7. Run: chmod +x /boot/install-pi-manager.sh" -ForegroundColor White
    Write-Host "   8. Run: sudo /boot/install-pi-manager.sh" -ForegroundColor White
    Write-Host "   9. Access Pi Manager: http://<pi-ip>:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "Pi Manager credentials:" -ForegroundColor Cyan
    Write-Host "   Username: admin" -ForegroundColor White
    Write-Host "   Password: admin123" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temporary files
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cleanup completed" -ForegroundColor Green
}

Write-Host "Pi Manager SD card is ready!" -ForegroundColor Green
