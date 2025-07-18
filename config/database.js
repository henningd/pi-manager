const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'pi-manager.db');

let db = null;

function initDatabase() {
  return new Promise((resolve, reject) => {
    // Create data directory if it doesn't exist
    const fs = require('fs');
    const dataDir = path.dirname(DB_PATH);
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('Error opening database:', err);
        reject(err);
        return;
      }
      
      console.log('Connected to SQLite database');
      
      // Create tables
      db.serialize(() => {
        // Users table
        db.run(`CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);
        
        // Configuration table
        db.run(`CREATE TABLE IF NOT EXISTS config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);
        
        // Logs table
        db.run(`CREATE TABLE IF NOT EXISTS logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          level TEXT NOT NULL,
          message TEXT NOT NULL,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);
        
        // Insert default configuration
        const defaultConfig = [
          ['notification_url', ''],
          ['github_repo', ''],
          ['github_branch', 'main'],
          ['update_interval', '120'], // 2 minutes in seconds
          ['device_name', 'Raspberry Pi'],
          ['auto_update_enabled', 'true']
        ];
        
        const stmt = db.prepare('INSERT OR IGNORE INTO config (key, value) VALUES (?, ?)');
        defaultConfig.forEach(([key, value]) => {
          stmt.run(key, value);
        });
        stmt.finalize();
        
        // Create default admin user (password: admin123)
        const bcrypt = require('bcryptjs');
        const defaultPassword = bcrypt.hashSync('admin123', 10);
        db.run('INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)', 
               ['admin', defaultPassword]);
        
        resolve();
      });
    });
  });
}

function getDatabase() {
  return db;
}

function closeDatabase() {
  return new Promise((resolve) => {
    if (db) {
      db.close((err) => {
        if (err) {
          console.error('Error closing database:', err);
        } else {
          console.log('Database connection closed');
        }
        resolve();
      });
    } else {
      resolve();
    }
  });
}

// Configuration helpers
function getConfig(key) {
  return new Promise((resolve, reject) => {
    db.get('SELECT value FROM config WHERE key = ?', [key], (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row ? row.value : null);
      }
    });
  });
}

function setConfig(key, value) {
  return new Promise((resolve, reject) => {
    db.run('INSERT OR REPLACE INTO config (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)', 
           [key, value], function(err) {
      if (err) {
        reject(err);
      } else {
        resolve(this.changes);
      }
    });
  });
}

function getAllConfig() {
  return new Promise((resolve, reject) => {
    db.all('SELECT key, value FROM config', (err, rows) => {
      if (err) {
        reject(err);
      } else {
        const config = {};
        rows.forEach(row => {
          config[row.key] = row.value;
        });
        resolve(config);
      }
    });
  });
}

// Logging helpers
function logMessage(level, message) {
  return new Promise((resolve, reject) => {
    db.run('INSERT INTO logs (level, message) VALUES (?, ?)', [level, message], function(err) {
      if (err) {
        reject(err);
      } else {
        resolve(this.lastID);
      }
    });
  });
}

function getLogs(limit = 100) {
  return new Promise((resolve, reject) => {
    db.all('SELECT * FROM logs ORDER BY timestamp DESC LIMIT ?', [limit], (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

module.exports = {
  initDatabase,
  getDatabase,
  closeDatabase,
  getConfig,
  setConfig,
  getAllConfig,
  logMessage,
  getLogs
};
