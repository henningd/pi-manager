const express = require('express');
const { exec } = require('child_process');
const os = require('os');
const fs = require('fs');
const { getAllConfig, setConfig, getLogs, logMessage } = require('../config/database');

const router = express.Router();

// Get system status
router.get('/status', async (req, res) => {
  try {
    const status = {
      timestamp: new Date().toISOString(),
      uptime: os.uptime(),
      loadavg: os.loadavg(),
      memory: {
        total: os.totalmem(),
        free: os.freemem(),
        used: os.totalmem() - os.freemem()
      },
      cpu: os.cpus(),
      platform: os.platform(),
      arch: os.arch(),
      hostname: os.hostname(),
      network: os.networkInterfaces(),
      online: true
    };
    
    res.json(status);
  } catch (error) {
    console.error('Status error:', error);
    res.status(500).json({ error: 'Failed to get system status' });
  }
});

// Reboot system
router.post('/reboot', async (req, res) => {
  try {
    await logMessage('info', `System reboot requested by user: ${req.user.username}`);
    
    // Send offline notification before reboot
    const notificationService = require('../services/notifier');
    await notificationService.sendOfflineNotification('System reboot initiated');
    
    res.json({ success: true, message: 'System reboot initiated' });
    
    // Delay reboot to allow response to be sent
    setTimeout(() => {
      exec('sudo reboot', (error) => {
        if (error) {
          console.error('Reboot error:', error);
        }
      });
    }, 2000);
    
  } catch (error) {
    console.error('Reboot error:', error);
    await logMessage('error', `Reboot error: ${error.message}`);
    res.status(500).json({ error: 'Failed to reboot system' });
  }
});

// Shutdown system
router.post('/shutdown', async (req, res) => {
  try {
    await logMessage('info', `System shutdown requested by user: ${req.user.username}`);
    
    // Send offline notification before shutdown
    const notificationService = require('../services/notifier');
    await notificationService.sendOfflineNotification('System shutdown initiated');
    
    res.json({ success: true, message: 'System shutdown initiated' });
    
    // Delay shutdown to allow response to be sent
    setTimeout(() => {
      exec('sudo shutdown -h now', (error) => {
        if (error) {
          console.error('Shutdown error:', error);
        }
      });
    }, 2000);
    
  } catch (error) {
    console.error('Shutdown error:', error);
    await logMessage('error', `Shutdown error: ${error.message}`);
    res.status(500).json({ error: 'Failed to shutdown system' });
  }
});

// Get configuration
router.get('/config', async (req, res) => {
  try {
    const config = await getAllConfig();
    res.json(config);
  } catch (error) {
    console.error('Config get error:', error);
    res.status(500).json({ error: 'Failed to get configuration' });
  }
});

// Update configuration
router.post('/config', async (req, res) => {
  try {
    const updates = req.body;
    const results = {};
    
    for (const [key, value] of Object.entries(updates)) {
      await setConfig(key, value);
      results[key] = value;
    }
    
    await logMessage('info', `Configuration updated by user: ${req.user.username}`);
    res.json({ success: true, updated: results });
    
  } catch (error) {
    console.error('Config update error:', error);
    await logMessage('error', `Config update error: ${error.message}`);
    res.status(500).json({ error: 'Failed to update configuration' });
  }
});

// Get logs
router.get('/logs', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;
    const logs = await getLogs(limit);
    res.json(logs);
  } catch (error) {
    console.error('Logs error:', error);
    res.status(500).json({ error: 'Failed to get logs' });
  }
});

// Test notification
router.post('/test-notification', async (req, res) => {
  try {
    const { message } = req.body;
    const notificationService = require('../services/notifier');
    
    await notificationService.sendNotification(message || 'Test notification from Pi Manager');
    await logMessage('info', `Test notification sent by user: ${req.user.username}`);
    
    res.json({ success: true, message: 'Test notification sent' });
  } catch (error) {
    console.error('Test notification error:', error);
    await logMessage('error', `Test notification error: ${error.message}`);
    res.status(500).json({ error: 'Failed to send test notification' });
  }
});

// Trigger manual update check
router.post('/update-check', async (req, res) => {
  try {
    const updaterService = require('../services/updater');
    const result = await updaterService.checkForUpdates();
    
    await logMessage('info', `Manual update check triggered by user: ${req.user.username}`);
    res.json({ success: true, result });
    
  } catch (error) {
    console.error('Update check error:', error);
    await logMessage('error', `Update check error: ${error.message}`);
    res.status(500).json({ error: 'Failed to check for updates' });
  }
});

// Check for image updates
router.post('/image-update-check', async (req, res) => {
  try {
    const updaterService = require('../services/updater');
    const result = await updaterService.checkForImageUpdates();
    
    await logMessage('info', `Manual image update check triggered by user: ${req.user.username}`);
    res.json({ success: true, result });
    
  } catch (error) {
    console.error('Image update check error:', error);
    await logMessage('error', `Image update check error: ${error.message}`);
    res.status(500).json({ error: 'Failed to check for image updates' });
  }
});

// Get available image update info
router.get('/image-update-status', async (req, res) => {
  try {
    const updaterService = require('../services/updater');
    const availableUpdate = updaterService.getAvailableImageUpdate();
    
    res.json({ 
      success: true, 
      has_update: !!availableUpdate,
      update_info: availableUpdate 
    });
    
  } catch (error) {
    console.error('Image update status error:', error);
    res.status(500).json({ error: 'Failed to get image update status' });
  }
});

// Get disk usage
router.get('/disk-usage', (req, res) => {
  exec('df -h /', (error, stdout, stderr) => {
    if (error) {
      console.error('Disk usage error:', error);
      return res.status(500).json({ error: 'Failed to get disk usage' });
    }
    
    const lines = stdout.trim().split('\n');
    if (lines.length >= 2) {
      const data = lines[1].split(/\s+/);
      res.json({
        filesystem: data[0],
        size: data[1],
        used: data[2],
        available: data[3],
        use_percentage: data[4],
        mounted_on: data[5]
      });
    } else {
      res.status(500).json({ error: 'Failed to parse disk usage' });
    }
  });
});

// Get temperature (Raspberry Pi specific)
router.get('/temperature', (req, res) => {
  fs.readFile('/sys/class/thermal/thermal_zone0/temp', 'utf8', (err, data) => {
    if (err) {
      console.error('Temperature read error:', err);
      return res.status(500).json({ error: 'Failed to read temperature' });
    }
    
    const temp = parseInt(data) / 1000; // Convert from millidegrees to degrees
    res.json({
      celsius: temp,
      fahrenheit: (temp * 9/5) + 32
    });
  });
});

// Get network info
router.get('/network', (req, res) => {
  const interfaces = os.networkInterfaces();
  const networkInfo = {};
  
  for (const [name, addresses] of Object.entries(interfaces)) {
    networkInfo[name] = addresses.filter(addr => !addr.internal);
  }
  
  res.json(networkInfo);
});

module.exports = router;
