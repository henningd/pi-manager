const { logMessage } = require('../config/database');
const notifier = require('./notifier');
const updater = require('./updater');

class MonitorService {
  constructor() {
    this.isRunning = false;
    this.heartbeatInterval = null;
    this.statusInterval = null;
  }
  
  async start() {
    if (this.isRunning) {
      console.log('Monitor service already running');
      return;
    }
    
    this.isRunning = true;
    console.log('Starting monitor service...');
    
    // Wait a moment for database to be fully initialized
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Send initial online notification
    try {
      await notifier.sendOnlineNotification('System started');
      await logMessage('info', 'Monitor service started');
    } catch (error) {
      console.error('Failed to send initial notification:', error);
      await logMessage('warning', 'Monitor service started but initial notification failed');
    }
    
    // Start heartbeat (every 5 minutes)
    this.heartbeatInterval = setInterval(async () => {
      try {
        await notifier.sendHeartbeat();
      } catch (error) {
        console.error('Heartbeat error:', error);
      }
    }, 5 * 60 * 1000);
    
    // Start system status updates (every 15 minutes)
    this.statusInterval = setInterval(async () => {
      try {
        await notifier.sendSystemStatus();
      } catch (error) {
        console.error('Status update error:', error);
      }
    }, 15 * 60 * 1000);
    
    // Start update scheduler
    try {
      await updater.startUpdateScheduler();
    } catch (error) {
      console.error('Update scheduler error:', error);
      await logMessage('error', `Update scheduler failed to start: ${error.message}`);
    }
    
    // Setup graceful shutdown handlers
    this.setupShutdownHandlers();
    
    console.log('Monitor service started successfully');
  }
  
  async stop() {
    if (!this.isRunning) {
      return;
    }
    
    console.log('Stopping monitor service...');
    this.isRunning = false;
    
    // Clear intervals
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
    
    if (this.statusInterval) {
      clearInterval(this.statusInterval);
      this.statusInterval = null;
    }
    
    // Send offline notification
    await notifier.sendOfflineNotification('System stopping');
    await logMessage('info', 'Monitor service stopped');
    
    console.log('Monitor service stopped');
  }
  
  setupShutdownHandlers() {
    // Handle various shutdown signals
    const shutdownHandler = async (signal) => {
      console.log(`Received ${signal}, shutting down gracefully...`);
      await this.stop();
      process.exit(0);
    };
    
    process.on('SIGTERM', () => shutdownHandler('SIGTERM'));
    process.on('SIGINT', () => shutdownHandler('SIGINT'));
    process.on('SIGUSR2', () => shutdownHandler('SIGUSR2')); // PM2 reload
    
    // Handle uncaught exceptions
    process.on('uncaughtException', async (error) => {
      console.error('Uncaught Exception:', error);
      await logMessage('error', `Uncaught exception: ${error.message}`);
      await notifier.sendOfflineNotification('System crashed - uncaught exception');
      process.exit(1);
    });
    
    // Handle unhandled promise rejections
    process.on('unhandledRejection', async (reason, promise) => {
      console.error('Unhandled Rejection at:', promise, 'reason:', reason);
      await logMessage('error', `Unhandled rejection: ${reason}`);
      await notifier.sendNotification('System warning - unhandled promise rejection', 'warning');
    });
  }
  
  async getSystemHealth() {
    const os = require('os');
    const fs = require('fs');
    
    try {
      // Get basic system info
      const health = {
        timestamp: new Date().toISOString(),
        uptime: os.uptime(),
        loadavg: os.loadavg(),
        memory: {
          total: os.totalmem(),
          free: os.freemem(),
          used: os.totalmem() - os.freemem(),
          usage_percent: ((os.totalmem() - os.freemem()) / os.totalmem() * 100).toFixed(2)
        },
        cpu: {
          count: os.cpus().length,
          model: os.cpus()[0]?.model || 'Unknown',
          load_1min: os.loadavg()[0],
          load_5min: os.loadavg()[1],
          load_15min: os.loadavg()[2]
        },
        platform: os.platform(),
        arch: os.arch(),
        hostname: os.hostname()
      };
      
      // Get temperature if available (Raspberry Pi)
      try {
        const tempData = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
        health.temperature = {
          celsius: parseInt(tempData) / 1000,
          fahrenheit: (parseInt(tempData) / 1000 * 9/5) + 32
        };
      } catch (e) {
        // Temperature not available
      }
      
      // Get disk usage
      try {
        const { exec } = require('child_process');
        const diskUsage = await new Promise((resolve, reject) => {
          exec('df -h /', (error, stdout, stderr) => {
            if (error) {
              reject(error);
            } else {
              const lines = stdout.trim().split('\n');
              if (lines.length >= 2) {
                const data = lines[1].split(/\s+/);
                resolve({
                  filesystem: data[0],
                  size: data[1],
                  used: data[2],
                  available: data[3],
                  use_percentage: data[4],
                  mounted_on: data[5]
                });
              } else {
                reject(new Error('Failed to parse disk usage'));
              }
            }
          });
        });
        health.disk = diskUsage;
      } catch (e) {
        // Disk usage not available
      }
      
      // Determine overall health status
      const memoryUsage = parseFloat(health.memory.usage_percent);
      const cpuLoad = health.cpu.load_1min;
      const tempCelsius = health.temperature?.celsius || 0;
      
      let status = 'healthy';
      const warnings = [];
      
      if (memoryUsage > 90) {
        status = 'critical';
        warnings.push('High memory usage');
      } else if (memoryUsage > 80) {
        status = 'warning';
        warnings.push('Elevated memory usage');
      }
      
      if (cpuLoad > 4) {
        status = 'critical';
        warnings.push('High CPU load');
      } else if (cpuLoad > 2) {
        if (status !== 'critical') status = 'warning';
        warnings.push('Elevated CPU load');
      }
      
      if (tempCelsius > 80) {
        status = 'critical';
        warnings.push('High temperature');
      } else if (tempCelsius > 70) {
        if (status !== 'critical') status = 'warning';
        warnings.push('Elevated temperature');
      }
      
      health.status = status;
      health.warnings = warnings;
      
      return health;
      
    } catch (error) {
      console.error('System health check error:', error);
      return {
        timestamp: new Date().toISOString(),
        status: 'error',
        error: error.message
      };
    }
  }
  
  async performHealthCheck() {
    try {
      const health = await this.getSystemHealth();
      
      // Log health status
      await logMessage('info', `System health: ${health.status}`);
      
      // Send notifications for critical issues
      if (health.status === 'critical' && health.warnings.length > 0) {
        await notifier.sendNotification(
          `System health critical: ${health.warnings.join(', ')}`,
          'critical'
        );
      }
      
      return health;
      
    } catch (error) {
      console.error('Health check error:', error);
      await logMessage('error', `Health check failed: ${error.message}`);
      return null;
    }
  }
}

module.exports = new MonitorService();
