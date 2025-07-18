# Pi Manager Master Image Creation Script for Windows
# This script creates a master image from your configured SD card

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDrive,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\temp\pi-manager-master-image.img",
    
    [Parameter(Mandatory=$false)]
    [switch]$Compress = $true
)

Write-Host "🥧 Pi Manager Master Image Creation" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
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
Write-Host "   Compression: $Compress" -ForegroundColor White
Write-Host ""

# Confirm before proceeding
Write-Host "⚠️  This will create a complete image of drive $SourcePath" -ForegroundColor Yellow
Write-Host "   This process may take 10-30 minutes depending on SD card size" -ForegroundColor Yellow
Write-Host ""
$confirmation = Read-Host "Continue with image creation? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "❌ Operation cancelled" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "📸 Creating image..." -ForegroundColor Cyan
    Write-Host "   This may take 10-30 minutes depending on SD card size" -ForegroundColor Yellow
    
    # Simple method: Use Raspberry Pi Imager if available
    $RpiImagerPath = Get-Command "rpi-imager.exe" -ErrorAction SilentlyContinue
    if (-not $RpiImagerPath) {
        $CommonPaths = @(
            "${env:ProgramFiles}\Raspberry Pi Imager\rpi-imager.exe",
            "${env:ProgramFiles(x86)}\Raspberry Pi Imager\rpi-imager.exe",
            "${env:LOCALAPPDATA}\Programs\Raspberry Pi Imager\rpi-imager.exe"
        )
        
        foreach ($Path in $CommonPaths) {
            if (Test-Path $Path) {
                $RpiImagerPath = Get-Command $Path
                break
            }
        }
    }
    
    if ($RpiImagerPath) {
        Write-Host "✅ Using Raspberry Pi Imager for image creation..." -ForegroundColor Green
        Write-Host "   Please use the GUI to create the image from drive $SourcePath" -ForegroundColor Yellow
        Write-Host "   Save the image to: $OutputPath" -ForegroundColor Yellow
        Start-Process -FilePath $RpiImagerPath.Source -Wait
    }
    else {
        # Try Win32DiskImager
        $Win32DiskImagerPath = Get-Command "Win32DiskImager.exe" -ErrorAction SilentlyContinue
        if (-not $Win32DiskImagerPath) {
            $CommonPaths = @(
                "${env:ProgramFiles}\ImageWriter\Win32DiskImager.exe",
                "${env:ProgramFiles(x86)}\ImageWriter\Win32DiskImager.exe"
            )
            
            foreach ($Path in $CommonPaths) {
                if (Test-Path $Path) {
                    $Win32DiskImagerPath = Get-Command $Path
                    break
                }
            }
        }
        
        if ($Win32DiskImagerPath) {
            Write-Host "✅ Using Win32DiskImager for image creation..." -ForegroundColor Green
            Write-Host "   Please use the GUI to create the image from drive $SourcePath" -ForegroundColor Yellow
            Write-Host "   Save the image to: $OutputPath" -ForegroundColor Yellow
            Start-Process -FilePath $Win32DiskImagerPath.Source -Wait
        }
        else {
            Write-Host "❌ No suitable imaging tool found" -ForegroundColor Red
            Write-Host "📥 Please install one of these tools:" -ForegroundColor Yellow
            Write-Host "   - Raspberry Pi Imager: https://www.raspberrypi.org/software/" -ForegroundColor White
            Write-Host "   - Win32DiskImager: https://sourceforge.net/projects/win32diskimager/" -ForegroundColor White
            Write-Host ""
            Write-Host "💡 Manual process:" -ForegroundColor Cyan
            Write-Host "   1. Install Raspberry Pi Imager" -ForegroundColor White
            Write-Host "   2. Choose 'Use custom image'" -ForegroundColor White
            Write-Host "   3. Select your SD card (drive $SourcePath)" -ForegroundColor White
            Write-Host "   4. Click 'Write' to create the image" -ForegroundColor White
            exit 1
        }
    }
    
    # Wait for user to complete the process
    Write-Host ""
    Write-Host "⏳ Waiting for image creation to complete..." -ForegroundColor Cyan
    Read-Host "Press Enter when you have saved the image to $OutputPath"
    
    # Verify image was created
    if (-not (Test-Path $OutputPath)) {
        Write-Host "❌ Image file not found at $OutputPath" -ForegroundColor Red
        Write-Host "💡 Please ensure you saved the image to the correct location" -ForegroundColor Yellow
        exit 1
    }
    
    $imageSize = (Get-Item $OutputPath).Length
    $imageSizeMB = [math]::Round($imageSize / 1MB, 2)
    
    Write-Host "✅ Image created successfully!" -ForegroundColor Green
    Write-Host "   Size: $imageSizeMB MB" -ForegroundColor White
    Write-Host "   Path: $OutputPath" -ForegroundColor White
    
    # Compress image if requested
    if ($Compress) {
        Write-Host "📦 Compressing image..." -ForegroundColor Cyan
        $compressedPath = $OutputPath -replace '\.img$', '.img.gz'
        
        # Check if 7-Zip is available
        $sevenZipPath = Get-Command "7z.exe" -ErrorAction SilentlyContinue
        if (-not $sevenZipPath) {
            $CommonPaths = @(
                "${env:ProgramFiles}\7-Zip\7z.exe",
                "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
            )
            
            foreach ($Path in $CommonPaths) {
                if (Test-Path $Path) {
                    $sevenZipPath = Get-Command $Path
                    break
                }
            }
        }
        
        if ($sevenZipPath) {
            & $sevenZipPath.Source a -tgzip $compressedPath $OutputPath
            
            if (Test-Path $compressedPath) {
                $compressedSize = (Get-Item $compressedPath).Length
                $compressedSizeMB = [math]::Round($compressedSize / 1MB, 2)
                $compressionRatio = [math]::Round(($compressedSize / $imageSize) * 100, 1)
                
                Write-Host "✅ Image compressed successfully!" -ForegroundColor Green
                Write-Host "   Original: $imageSizeMB MB" -ForegroundColor White
                Write-Host "   Compressed: $compressedSizeMB MB ($compressionRatio%)" -ForegroundColor White
                Write-Host "   Path: $compressedPath" -ForegroundColor White
                
                $keepOriginal = Read-Host "Keep original uncompressed image? (yes/no)"
                if ($keepOriginal -ne "yes") {
                    Remove-Item $OutputPath -Force
                    Write-Host "🧹 Original image removed" -ForegroundColor Green
                }
            }
        }
        else {
            Write-Host "⚠️  7-Zip not found, skipping compression" -ForegroundColor Yellow
            Write-Host "   Install 7-Zip for compression: https://www.7-zip.org/" -ForegroundColor White
        }
    }
    
    # Create image info file
    $infoPath = $OutputPath -replace '\.img(\.gz)?$', '.txt'
    $imageInfo = @"
🥧 Pi Manager Master Image
=========================

Created: $(Get-Date)
Source Drive: $SourcePath
Image Size: $imageSizeMB MB
Compression: $Compress

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
1. Flash this image to new SD cards using:
   - Raspberry Pi Imager
   - Win32DiskImager
   - dd command

2. Insert SD card into Pi and power on

3. Pi Manager will be available at:
   http://<PI-IP>:3000

4. SSH access:
   ssh pi@<PI-IP>
   Password: ecomo

Created with: Pi Manager Image Creation Tools
"@
    
    Set-Content -Path $infoPath -Value $imageInfo -Encoding UTF8
    Write-Host "📄 Image info created: $infoPath" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎉 Master Image Creation Complete!" -ForegroundColor Green
    Write-Host "===================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Summary:" -ForegroundColor Cyan
    Write-Host "   ✅ Master image created from $SourcePath" -ForegroundColor White
    Write-Host "   ✅ Image saved to: $OutputPath" -ForegroundColor White
    if ($Compress -and (Test-Path ($OutputPath -replace '\.img$', '.img.gz'))) {
        Write-Host "   ✅ Compressed image available" -ForegroundColor White
    }
    Write-Host "   ✅ Image info file created" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. This image can now be flashed to new SD cards" -ForegroundColor White
    Write-Host "   2. Each new Pi will have Pi Manager pre-installed" -ForegroundColor White
    Write-Host "   3. SSH will be enabled with password: ecomo" -ForegroundColor White
    Write-Host "   4. Pi Manager will be accessible at: http://<PI-IP>:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 For flashing to new SD cards, use:" -ForegroundColor Cyan
    Write-Host "   - Raspberry Pi Imager (recommended)" -ForegroundColor White
    Write-Host "   - Win32DiskImager" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "🥧 Master image is ready for deployment!" -ForegroundColor Green
