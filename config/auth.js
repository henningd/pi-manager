const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { getDatabase } = require('./database');

const JWT_SECRET = process.env.JWT_SECRET || 'pi-manager-secret-key-change-in-production';
const JWT_EXPIRES_IN = '24h';

function generateToken(user) {
  return jwt.sign(
    { 
      id: user.id, 
      username: user.username 
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }

  req.user = decoded;
  next();
}

function authenticateUser(username, password) {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    
    db.get('SELECT * FROM users WHERE username = ?', [username], (err, user) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (!user) {
        resolve(null); // User not found
        return;
      }
      
      bcrypt.compare(password, user.password, (err, isMatch) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (isMatch) {
          resolve({
            id: user.id,
            username: user.username,
            created_at: user.created_at
          });
        } else {
          resolve(null); // Password doesn't match
        }
      });
    });
  });
}

function createUser(username, password) {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    
    bcrypt.hash(password, 10, (err, hashedPassword) => {
      if (err) {
        reject(err);
        return;
      }
      
      db.run('INSERT INTO users (username, password) VALUES (?, ?)', 
             [username, hashedPassword], function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({
            id: this.lastID,
            username: username
          });
        }
      });
    });
  });
}

function changePassword(userId, oldPassword, newPassword) {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    
    // First verify old password
    db.get('SELECT password FROM users WHERE id = ?', [userId], (err, user) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (!user) {
        reject(new Error('User not found'));
        return;
      }
      
      bcrypt.compare(oldPassword, user.password, (err, isMatch) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (!isMatch) {
          reject(new Error('Current password is incorrect'));
          return;
        }
        
        // Hash new password and update
        bcrypt.hash(newPassword, 10, (err, hashedPassword) => {
          if (err) {
            reject(err);
            return;
          }
          
          db.run('UPDATE users SET password = ? WHERE id = ?', 
                 [hashedPassword, userId], function(err) {
            if (err) {
              reject(err);
            } else {
              resolve(this.changes > 0);
            }
          });
        });
      });
    });
  });
}

module.exports = {
  generateToken,
  verifyToken,
  authenticateToken,
  authenticateUser,
  createUser,
  changePassword,
  JWT_SECRET
};
