#!/bin/bash
# Emergency Fix Script for Pi Manager Installation
# This script creates the missing install-pi-manager.sh and runs it

echo "🚨 Pi Manager Emergency Fix Script"
echo "=================================="
echo ""

# Check if we're on a Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "❌ This script is designed for Raspberry Pi only!"
    exit 1
fi

# Check internet connection
if ! ping -c 1 google.com > /dev/null 2>&1; then
    echo "❌ No internet connection. Please connect to the internet first."
    echo "💡 Tip: Connect ethernet cable or configure WiFi"
    exit 1
fi

echo "📋 System Information:"
echo "   Hostname: $(hostname)"
echo "   IP Address: $(hostname -I | awk '{print $1}')"
echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   User: $(whoami)"
echo ""

# Create the install-pi-manager.sh script
echo "📝 Creating install-pi-manager.sh script..."

cat > /home/pi/install-pi-manager.sh << 'EOF'
#!/bin/bash
# Pi Manager Auto-Install Script
# This script installs Pi Manager on a fresh Raspberry Pi OS installation

echo "🥧 Starting Pi Manager installation..."
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script with sudo"
    echo "Usage: sudo ./install-pi-manager.sh"
    exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

echo "📋 Installation Configuration:"
echo "   User: $ACTUAL_USER"
echo "   Home: $USER_HOME"
echo "   System: $(uname -a)"
echo ""

# Update system
echo "📦 Updating system packages..."
apt update
apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
apt install -y curl git build-essential

# Install Node.js 18.x
echo "📦 Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify Node.js installation
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "✅ Node.js installed: $NODE_VERSION"
echo "✅ npm installed: $NPM_VERSION"

# Clone Pi Manager from GitHub
echo "📥 Cloning Pi Manager from GitHub..."
cd $USER_HOME

# Remove existing directory if it exists
if [ -d "pi-manager" ]; then
    echo "⚠️  Removing existing pi-manager directory..."
    rm -rf pi-manager
fi

# Clone as the actual user, not root
sudo -u $ACTUAL_USER git clone https://github.com/henningd/pi-manager.git
cd pi-manager

# Install dependencies
echo "📦 Installing Pi Manager dependencies..."
sudo -u $ACTUAL_USER npm install --production

# Create data directory
echo "📁 Creating data directory..."
mkdir -p data
chown $ACTUAL_USER:$ACTUAL_USER data

# Set up systemd service
echo "⚙️ Setting up systemd service..."
cp scripts/pi-manager.service /etc/systemd/system/

# Update service file with correct paths
sed -i "s|/opt/pi-manager|$USER_HOME/pi-manager|g" /etc/systemd/system/pi-manager.service
sed -i "s|User=pi|User=$ACTUAL_USER|g" /etc/systemd/system/pi-manager.service

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable pi-manager

# Configure system locale and timezone
echo "🌍 Configuring system locale..."
timedatectl set-timezone Europe/Berlin

# Configure keyboard layout
echo "⌨️ Configuring German keyboard layout..."
echo 'XKBLAYOUT="de"' >> /etc/default/keyboard

# Enable SSH (if not already enabled)
echo "🔐 Ensuring SSH is enabled..."
systemctl enable ssh
systemctl start ssh

# Create initial admin user in database
echo "👤 Setting up initial admin user..."
cd $USER_HOME/pi-manager

# Start the service
echo "🚀 Starting Pi Manager service..."
systemctl start pi-manager

# Wait a moment for the service to start
sleep 3

# Check service status
if systemctl is-active --quiet pi-manager; then
    echo "✅ Pi Manager service started successfully"
    
    # Get the Pi's IP address
    PI_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "🎉 Pi Manager installation completed successfully!"
    echo "=============================================="
    echo ""
    echo "📋 Access Information:"
    echo "   🌐 Web Interface: http://$PI_IP:3000"
    echo "   🔐 Username: admin"
    echo "   🔐 Password: admin123"
    echo ""
    echo "📋 SSH Access:"
    echo "   🔗 Command: ssh $ACTUAL_USER@$PI_IP"
    echo "   🔐 Password: ecomo"
    echo ""
    echo "📋 Service Management:"
    echo "   ▶️  Start:   sudo systemctl start pi-manager"
    echo "   ⏹️  Stop:    sudo systemctl stop pi-manager"
    echo "   🔄 Restart: sudo systemctl restart pi-manager"
    echo "   📊 Status:  sudo systemctl status pi-manager"
    echo "   📝 Logs:    sudo journalctl -u pi-manager -f"
    echo ""
    echo "⚠️  Important: Change the default password after first login!"
    echo ""
    echo "🥧 Pi Manager is ready to use!"
    
else
    echo "❌ Pi Manager service failed to start"
    echo "📝 Check logs with: sudo journalctl -u pi-manager -f"
    echo "🔧 Try manual start: sudo systemctl start pi-manager"
    exit 1
fi

# Clean up
echo "🧹 Cleaning up installation files..."
rm -f /boot/install-pi-manager.sh

echo ""
echo "✅ Installation complete! Enjoy your Pi Manager! 🥧"
EOF

# Make the script executable
chmod +x /home/pi/install-pi-manager.sh

echo "✅ install-pi-manager.sh created successfully!"
echo ""

# Ask user if they want to run the installation immediately
echo "🤔 Do you want to run the Pi Manager installation now?"
echo "   This will take 5-10 minutes and requires internet connection."
echo ""
read -p "Run installation now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting Pi Manager installation..."
    echo "======================================"
    sudo /home/pi/install-pi-manager.sh
else
    echo "⏳ Installation postponed."
    echo ""
    echo "📋 To run the installation later, use:"
    echo "   sudo /home/pi/install-pi-manager.sh"
    echo ""
    echo "📋 The script is now available at: /home/pi/install-pi-manager.sh"
fi

echo ""
echo "🎉 Emergency fix completed!"
