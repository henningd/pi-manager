#!/bin/bash

# Pi Manager Installation Script
# This script sets up the Pi Manager system on a Raspberry Pi

set -e

echo "🥧 Pi Manager Installation Script"
echo "================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please do not run this script as root"
    exit 1
fi

# Variables
PI_MANAGER_DIR="/opt/pi-manager"
SERVICE_FILE="/etc/systemd/system/pi-manager.service"
CURRENT_DIR=$(pwd)

echo "📋 Starting installation..."

# Update system
echo "🔄 Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "✅ Node.js already installed"
fi

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📦 Installing Git..."
    sudo apt install -y git
else
    echo "✅ Git already installed"
fi

# Install additional system packages
echo "📦 Installing system dependencies..."
sudo apt install -y curl wget unzip sqlite3

# Create pi-manager directory
echo "📁 Creating application directory..."
sudo mkdir -p $PI_MANAGER_DIR
sudo chown pi:pi $PI_MANAGER_DIR

# Copy application files
echo "📋 Copying application files..."
cp -r $CURRENT_DIR/* $PI_MANAGER_DIR/
cd $PI_MANAGER_DIR

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production

# Create data directory
mkdir -p data
mkdir -p backups

# Set up systemd service
echo "⚙️ Setting up systemd service..."
sudo cp scripts/pi-manager.service $SERVICE_FILE
sudo systemctl daemon-reload
sudo systemctl enable pi-manager

# Configure system settings
echo "⚙️ Configuring system settings..."

# Set German keyboard layout
sudo sed -i 's/XKBLAYOUT=".*"/XKBLAYOUT="de"/' /etc/default/keyboard

# Set timezone to Europe/Berlin
sudo timedatectl set-timezone Europe/Berlin

# Enable SSH if not already enabled
sudo systemctl enable ssh

# Configure sudoers for reboot/shutdown without password
echo "pi ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/shutdown" | sudo tee /etc/sudoers.d/pi-manager

# Set up firewall (optional)
if command -v ufw &> /dev/null; then
    echo "🔒 Configuring firewall..."
    sudo ufw allow 22/tcp   # SSH
    sudo ufw allow 3000/tcp # Pi Manager
    sudo ufw --force enable
fi

# Start the service
echo "🚀 Starting Pi Manager service..."
sudo systemctl start pi-manager

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet pi-manager; then
    echo "✅ Pi Manager service is running"
else
    echo "❌ Pi Manager service failed to start"
    echo "📋 Service status:"
    sudo systemctl status pi-manager
    exit 1
fi

# Get IP address for access info
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Installation completed successfully!"
echo "=================================="
echo ""
echo "📱 Access Pi Manager at:"
echo "   http://$IP_ADDRESS:3000"
echo "   http://localhost:3000 (if accessing locally)"
echo ""
echo "🔐 Default login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "⚠️  Please change the default password after first login!"
echo ""
echo "📋 Useful commands:"
echo "   sudo systemctl status pi-manager    # Check service status"
echo "   sudo systemctl restart pi-manager   # Restart service"
echo "   sudo systemctl stop pi-manager      # Stop service"
echo "   sudo journalctl -u pi-manager -f    # View logs"
echo ""
echo "📁 Application directory: $PI_MANAGER_DIR"
echo ""

# Show service status
echo "📊 Current service status:"
sudo systemctl status pi-manager --no-pager -l

echo ""
echo "🥧 Pi Manager is ready to use!"
