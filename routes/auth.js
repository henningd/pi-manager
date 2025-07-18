const express = require('express');
const { authenticateUser, generateToken, changePassword } = require('../config/auth');
const { logMessage } = require('../config/database');

const router = express.Router();

// Login endpoint
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }
    
    const user = await authenticateUser(username, password);
    
    if (!user) {
      await logMessage('warning', `Failed login attempt for username: ${username}`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = generateToken(user);
    await logMessage('info', `User ${username} logged in successfully`);
    
    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username
      }
    });
    
  } catch (error) {
    console.error('Login error:', error);
    await logMessage('error', `Login error: ${error.message}`);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Change password endpoint
router.post('/change-password', async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }
    
    const { verifyToken } = require('../config/auth');
    const decoded = verifyToken(token);
    
    if (!decoded) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: 'Old and new passwords are required' });
    }
    
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters long' });
    }
    
    const success = await changePassword(decoded.id, oldPassword, newPassword);
    
    if (success) {
      await logMessage('info', `Password changed for user: ${decoded.username}`);
      res.json({ success: true, message: 'Password changed successfully' });
    } else {
      res.status(400).json({ error: 'Failed to change password' });
    }
    
  } catch (error) {
    console.error('Change password error:', error);
    await logMessage('error', `Change password error: ${error.message}`);
    
    if (error.message === 'Current password is incorrect') {
      res.status(400).json({ error: 'Current password is incorrect' });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// Verify token endpoint
router.get('/verify', (req, res) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  const { verifyToken } = require('../config/auth');
  const decoded = verifyToken(token);
  
  if (!decoded) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
  
  res.json({
    success: true,
    user: {
      id: decoded.id,
      username: decoded.username
    }
  });
});

module.exports = router;
