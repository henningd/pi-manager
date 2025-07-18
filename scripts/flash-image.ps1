# Pi Manager Image Flash Script for Windows
# This script provides guidance for setting up Pi Manager on Raspberry Pi

param(
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter
)

Write-Host "Pi Manager Image Flash Script" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Validate drive letter
if ($DriveLetter -notmatch '^[A-Z]$') {
    Write-Host "ERROR: Invalid drive letter. Please provide a single letter (e.g., D)" -ForegroundColor Red
    exit 1
}

$DrivePath = "${DriveLetter}:"

# Check if drive exists
if (-not (Test-Path $DrivePath)) {
    Write-Host "ERROR: Drive $DrivePath not found" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "   Target Drive: $DrivePath" -ForegroundColor White

Write-Host ""
Write-Host "This script provides guidance for manual setup with Raspberry Pi Imager." -ForegroundColor Yellow
Write-Host "Please follow the instructions in FLASH-ANLEITUNG.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick steps:" -ForegroundColor White
Write-Host "1. Install Raspberry Pi Imager from: https://www.raspberrypi.org/software/" -ForegroundColor White
Write-Host "2. Choose Raspberry Pi OS Lite" -ForegroundColor White
Write-Host "3. Configure advanced settings:" -ForegroundColor White
Write-Host "   - Enable SSH with username pi and password ecomo" -ForegroundColor White
Write-Host "   - Set locale to Germany and keyboard to de" -ForegroundColor White
Write-Host "4. Flash to SD card" -ForegroundColor White
Write-Host "5. Copy install-pi-manager.sh to boot partition" -ForegroundColor White
Write-Host ""
Write-Host "After Pi boots:" -ForegroundColor Cyan
Write-Host "1. SSH to pi with: ssh pi@pi-ip-address (password: ecomo)" -ForegroundColor White
Write-Host "2. Run: sudo /boot/install-pi-manager.sh" -ForegroundColor White
Write-Host "3. Access web interface: http://pi-ip-address:3000 (admin/admin123)" -ForegroundColor White
Write-Host ""
Write-Host "Files to copy to boot partition:" -ForegroundColor Cyan
Write-Host "   - install-pi-manager.sh (from project root)" -ForegroundColor White
Write-Host ""

# Check if install script exists
$InstallScript = "install-pi-manager.sh"
if (Test-Path $InstallScript) {
    Write-Host "SUCCESS: Found $InstallScript - ready to copy to boot partition" -ForegroundColor Green
} else {
    Write-Host "WARNING: $InstallScript not found in current directory" -ForegroundColor Red
}

Write-Host ""
Write-Host "Pi Manager SD card setup guide displayed!" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
