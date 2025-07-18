const axios = require('axios');
const { getConfig, logMessage } = require('../config/database');

class NotificationService {
  async sendNotification(message, type = 'info') {
    try {
      const notificationUrl = await getConfig('notification_url');
      const deviceName = await getConfig('device_name');
      
      if (!notificationUrl) {
        console.log('No notification URL configured, skipping notification');
        return false;
      }
      
      const payload = {
        device: deviceName || 'Raspberry Pi',
        message: message,
        type: type,
        timestamp: new Date().toISOString(),
        status: 'online'
      };
      
      const response = await axios.post(notificationUrl, payload, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Pi-Manager/1.0'
        }
      });
      
      await logMessage('info', `Notification sent: ${message}`);
      return true;
      
    } catch (error) {
      console.error('Notification error:', error.message);
      await logMessage('error', `Notification failed: ${error.message}`);
      return false;
    }
  }
  
  async sendOnlineNotification(additionalInfo = '') {
    const deviceName = await getConfig('device_name');
    const message = `${deviceName || 'Raspberry Pi'} is now online${additionalInfo ? ': ' + additionalInfo : ''}`;
    return this.sendNotification(message, 'online');
  }
  
  async sendOfflineNotification(reason = '') {
    const deviceName = await getConfig('device_name');
    const message = `${deviceName || 'Raspberry Pi'} is going offline${reason ? ': ' + reason : ''}`;
    return this.sendNotification(message, 'offline');
  }
  
  async sendHeartbeat() {
    try {
      const notificationUrl = await getConfig('notification_url');
      const deviceName = await getConfig('device_name');
      
      if (!notificationUrl) {
        return false;
      }
      
      const payload = {
        device: deviceName || 'Raspberry Pi',
        type: 'heartbeat',
        timestamp: new Date().toISOString(),
        status: 'online',
        uptime: process.uptime()
      };
      
      await axios.post(notificationUrl, payload, {
        timeout: 5000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Pi-Manager/1.0'
        }
      });
      
      return true;
      
    } catch (error) {
      console.error('Heartbeat error:', error.message);
      return false;
    }
  }
  
  async sendSystemStatus() {
    try {
      const os = require('os');
      const fs = require('fs');
      
      const notificationUrl = await getConfig('notification_url');
      const deviceName = await getConfig('device_name');
      
      if (!notificationUrl) {
        return false;
      }
      
      // Get temperature if available
      let temperature = null;
      try {
        const tempData = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
        temperature = parseInt(tempData) / 1000;
      } catch (e) {
        // Temperature not available
      }
      
      const payload = {
        device: deviceName || 'Raspberry Pi',
        type: 'status',
        timestamp: new Date().toISOString(),
        status: 'online',
        system: {
          uptime: os.uptime(),
          loadavg: os.loadavg(),
          memory: {
            total: os.totalmem(),
            free: os.freemem(),
            used: os.totalmem() - os.freemem()
          },
          temperature: temperature,
          hostname: os.hostname()
        }
      };
      
      await axios.post(notificationUrl, payload, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Pi-Manager/1.0'
        }
      });
      
      return true;
      
    } catch (error) {
      console.error('System status notification error:', error.message);
      return false;
    }
  }
}

module.exports = new NotificationService();
