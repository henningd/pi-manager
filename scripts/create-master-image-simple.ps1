# Pi Manager Master Image Creation Script for Windows
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDrive,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\temp\pi-manager-master-image.img"
)

Write-Host "🥧 Pi Manager Master Image Creation" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Validate source drive
if ($SourceDrive -notmatch '^[A-Z]$') {
    Write-Host "❌ Invalid drive letter. Please provide a single letter (e.g., D)" -ForegroundColor Red
    exit 1
}

$SourcePath = "${SourceDrive}:"

# Check if source drive exists
if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ Source drive $SourcePath not found" -ForegroundColor Red
    Write-Host "💡 Please ensure the SD card is inserted and recognized by Windows" -ForegroundColor Yellow
    exit 1
}

# Create output directory
$OutputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    Write-Host "📁 Created output directory: $OutputDir" -ForegroundColor Green
}

Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   Source Drive: $SourcePath" -ForegroundColor White
Write-Host "   Output Image: $OutputPath" -ForegroundColor White
Write-Host ""

# Confirm before proceeding
Write-Host "⚠️  This will create a complete image of drive $SourcePath" -ForegroundColor Yellow
Write-Host "   This process requires a disk imaging tool" -ForegroundColor Yellow
Write-Host ""
$confirmation = Read-Host "Continue with image creation? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "❌ Operation cancelled" -ForegroundColor Red
    exit 1
}

# Look for imaging tools
Write-Host "🔍 Looking for imaging tools..." -ForegroundColor Cyan

$toolFound = $false
$toolName = ""
$toolPath = ""

# Check for Raspberry Pi Imager
$RpiImagerPaths = @(
    "${env:ProgramFiles}\Raspberry Pi Imager\rpi-imager.exe",
    "${env:ProgramFiles(x86)}\Raspberry Pi Imager\rpi-imager.exe",
    "${env:LOCALAPPDATA}\Programs\Raspberry Pi Imager\rpi-imager.exe"
)

foreach ($Path in $RpiImagerPaths) {
    if (Test-Path $Path) {
        $toolFound = $true
        $toolName = "Raspberry Pi Imager"
        $toolPath = $Path
        break
    }
}

# Check for Win32DiskImager if RPI Imager not found
if (-not $toolFound) {
    $Win32DiskImagerPaths = @(
        "${env:ProgramFiles}\ImageWriter\Win32DiskImager.exe",
        "${env:ProgramFiles(x86)}\ImageWriter\Win32DiskImager.exe"
    )
    
    foreach ($Path in $Win32DiskImagerPaths) {
        if (Test-Path $Path) {
            $toolFound = $true
            $toolName = "Win32DiskImager"
            $toolPath = $Path
            break
        }
    }
}

if ($toolFound) {
    Write-Host "✅ Found $toolName" -ForegroundColor Green
    Write-Host "   Path: $toolPath" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🚀 Starting $toolName..." -ForegroundColor Cyan
    Write-Host "   Please use the tool to create an image from drive $SourcePath" -ForegroundColor Yellow
    Write-Host "   Save the image to: $OutputPath" -ForegroundColor Yellow
    Write-Host ""
    
    # Start the imaging tool
    Start-Process -FilePath $toolPath -Wait
    
    Write-Host "⏳ Waiting for image creation to complete..." -ForegroundColor Cyan
    Write-Host "   Press Enter when you have saved the image to $OutputPath" -ForegroundColor Yellow
    Read-Host
    
    # Verify image was created
    if (Test-Path $OutputPath) {
        $imageSize = (Get-Item $OutputPath).Length
        $imageSizeMB = [math]::Round($imageSize / 1MB, 2)
        
        Write-Host "✅ Image created successfully!" -ForegroundColor Green
        Write-Host "   Size: $imageSizeMB MB" -ForegroundColor White
        Write-Host "   Path: $OutputPath" -ForegroundColor White
        
        # Create image info file
        $infoPath = $OutputPath.Replace('.img', '.txt')
        $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        

Created: $currentDate
Source Drive: $SourcePath
Image Size: $imageSizeMB MB

Pi Manager Configuration:
- Pre-installed and configured
- Service enabled for auto-start
- Web Interface: http://<PI-IP>:3000
- Login: admin / admin123

SSH Access:
- User: pi
- Password: ecomo
- SSH enabled

System Configuration:
- Timezone: Europe/Berlin
- Keyboard: German (DE)
- Locale: German

Deployment Instructions:
1. Flash this image to new SD cards
2. Insert SD card into Pi and power on
3. Pi Manager will be available at: http://<PI-IP>:3000
4. SSH access: ssh pi@<PI-IP> (Password: ecomo)

Created with: Pi Manager Image Creation Tools
"@
        $imageInfo = "Pi Manager Master Image`r`n"
        $imageInfo += "========================`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "Created: $currentDate`r`n"
        $imageInfo += "Source Drive: $SourcePath`r`n"
        $imageInfo += "Image Size: $imageSizeMB MB`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "Pi Manager Configuration:`r`n"
        $imageInfo += "* Pre-installed and configured`r`n"
        $imageInfo += "* Service enabled for auto-start`r`n"
        $imageInfo += "* Web Interface: http://<PI-IP>:3000`r`n"
        $imageInfo += "* Login: admin / admin123`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "SSH Access:`r`n"
        $imageInfo += "* User: pi`r`n"
        $imageInfo += "* Password: ecomo`r`n"
        $imageInfo += "* SSH enabled`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "System Configuration:`r`n"
        $imageInfo += "* Timezone: Europe/Berlin`r`n"
        $imageInfo += "* Keyboard: German (DE)`r`n"
        $imageInfo += "* Locale: German`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "Deployment Instructions:`r`n"
        $imageInfo += "1. Flash this image to new SD cards`r`n"
        $imageInfo += "2. Insert SD card into Pi and power on`r`n"
        $imageInfo += "3. Pi Manager will be available at: http://<PI-IP>:3000`r`n"
        $imageInfo += "4. SSH access: ssh pi@<PI-IP> (Password: ecomo)`r`n"
        $imageInfo += "`r`n"
        $imageInfo += "Created with: Pi Manager Image Creation Tools`r`n"
========================

Created: $currentDate
Source Drive: $SourcePath
Image Size: $imageSizeMB MB

Pi Manager Configuration:
- Pre-installed and configured
- Service enabled for auto-start
- Web Interface: http://<PI-IP>:3000
- Login: admin / admin123

SSH Access:
- User: pi
- Password: ecomo
- SSH enabled

System Configuration:
- Timezone: Europe/Berlin
- Keyboard: German (DE)
- Locale: German

Deployment Instructions:
1. Flash this image to new SD cards
2. Insert SD card into Pi and power on
3. Pi Manager will be available at: http://<PI-IP>:3000
4. SSH access: ssh pi@<PI-IP> (Password: ecomo)

Created with: Pi Manager Image Creation Tools
"@
        
        Set-Content -Path $infoPath -Value $imageInfo -Encoding UTF8
        Write-Host "📄 Image info created: $infoPath" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "🎉 Master Image Creation Complete!" -ForegroundColor Green
        Write-Host "===================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "� Summary:" -ForegroundColor Cyan
        Write-Host "   ✅ Master image created from $SourcePath" -ForegroundColor White
        Write-Host "   ✅ Image saved to: $OutputPath" -ForegroundColor White
        Write-Host "   ✅ Image info file created" -ForegroundColor White
        Write-Host ""
        Write-Host "📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "   1. This image can now be flashed to new SD cards" -ForegroundColor White
        Write-Host "   2. Each new Pi will have Pi Manager pre-installed" -ForegroundColor White
        Write-Host "   3. SSH will be enabled with password: ecomo" -ForegroundColor White
        Write-Host "   4. Pi Manager will be accessible at: http://<PI-IP>:3000" -ForegroundColor White
        Write-Host ""
        Write-Host "🥧 Master image is ready for deployment!" -ForegroundColor Green
        
    } else {
        Write-Host "❌ Image file not found at $OutputPath" -ForegroundColor Red
        Write-Host "💡 Please ensure you saved the image to the correct location" -ForegroundColor Yellow
        exit 1
    }
    
} else {
    Write-Host "❌ No suitable imaging tool found" -ForegroundColor Red
    Write-Host ""
    Write-Host "📥 Please install one of these tools:" -ForegroundColor Yellow
    Write-Host "   - Raspberry Pi Imager: https://www.raspberrypi.org/software/" -ForegroundColor White
    Write-Host "   - Win32DiskImager: https://sourceforge.net/projects/win32diskimager/" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Manual process:" -ForegroundColor Cyan
    Write-Host "   1. Install Raspberry Pi Imager or Win32DiskImager" -ForegroundColor White
    Write-Host "   2. Use the tool to create an image from drive $SourcePath" -ForegroundColor White
    Write-Host "   3. Save the image to: $OutputPath" -ForegroundColor White
    Write-Host "   4. Run this script again to verify and create info file" -ForegroundColor White
    exit 1
}
