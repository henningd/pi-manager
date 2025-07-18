const simpleGit = require('simple-git');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const { getConfig, logMessage } = require('../config/database');
const notifier = require('./notifier');

class UpdaterService {
  constructor() {
    this.updateInProgress = false;
    this.appPath = path.join(__dirname, '..');
    this.lastImageCheck = null;
    this.availableImageUpdate = null;
  }
  
  async checkForUpdates() {
    if (this.updateInProgress) {
      return { status: 'update_in_progress' };
    }
    
    try {
      const githubRepo = await getConfig('github_repo');
      const githubBranch = await getConfig('github_branch') || 'main';
      const autoUpdateEnabled = await getConfig('auto_update_enabled') === 'true';
      
      if (!githubRepo) {
        return { status: 'no_repo_configured' };
      }
      
      const git = simpleGit(this.appPath);
      
      // Check if git repository exists
      const isRepo = await git.checkIsRepo();
      if (!isRepo) {
        await logMessage('info', 'Initializing git repository for updates');
        await this.initializeRepository(githubRepo, githubBranch);
        return { status: 'repository_initialized' };
      }
      
      // Fetch latest changes
      await git.fetch();
      
      // Get current and remote commit hashes
      const currentCommit = await git.revparse(['HEAD']);
      const remoteCommit = await git.revparse([`origin/${githubBranch}`]);
      
      if (currentCommit === remoteCommit) {
        return { status: 'up_to_date', current: currentCommit };
      }
      
      // Updates available
      const result = {
        status: 'updates_available',
        current: currentCommit,
        latest: remoteCommit,
        auto_update_enabled: autoUpdateEnabled
      };
      
      if (autoUpdateEnabled) {
        await logMessage('info', 'Auto-update enabled, applying updates');
        const updateResult = await this.applyUpdates();
        return { ...result, update_result: updateResult };
      }
      
      return result;
      
    } catch (error) {
      console.error('Update check error:', error);
      await logMessage('error', `Update check failed: ${error.message}`);
      return { status: 'error', error: error.message };
    }
  }
  
  async initializeRepository(repoUrl, branch = 'main') {
    try {
      const git = simpleGit(this.appPath);
      
      // Initialize git repository
      await git.init();
      await git.addRemote('origin', repoUrl);
      await git.fetch();
      await git.checkout(['-b', branch, `origin/${branch}`]);
      
      await logMessage('info', `Git repository initialized with ${repoUrl}`);
      return true;
      
    } catch (error) {
      console.error('Repository initialization error:', error);
      await logMessage('error', `Repository initialization failed: ${error.message}`);
      throw error;
    }
  }
  
  async applyUpdates() {
    if (this.updateInProgress) {
      return { status: 'update_in_progress' };
    }
    
    this.updateInProgress = true;
    
    try {
      const githubBranch = await getConfig('github_branch') || 'main';
      const git = simpleGit(this.appPath);
      
      // Create backup of current state
      const backupResult = await this.createBackup();
      if (!backupResult.success) {
        throw new Error('Failed to create backup');
      }
      
      // Pull latest changes
      await git.pull('origin', githubBranch);
      
      // Check if package.json changed and update dependencies
      const packageChanged = await this.checkPackageJsonChanged();
      if (packageChanged) {
        await logMessage('info', 'Package.json changed, updating dependencies');
        await this.updateDependencies();
      }
      
      // Restart application
      await logMessage('info', 'Update completed, restarting application');
      await notifier.sendNotification('Application updated and restarting');
      
      // Restart the application
      setTimeout(() => {
        process.exit(0); // PM2 or systemd will restart the application
      }, 2000);
      
      return { 
        status: 'success', 
        backup: backupResult.backupPath,
        package_updated: packageChanged 
      };
      
    } catch (error) {
      console.error('Update application error:', error);
      await logMessage('error', `Update failed: ${error.message}`);
      
      // Attempt to rollback
      try {
        await this.rollback();
        await logMessage('info', 'Rollback completed');
      } catch (rollbackError) {
        await logMessage('error', `Rollback failed: ${rollbackError.message}`);
      }
      
      return { status: 'error', error: error.message };
      
    } finally {
      this.updateInProgress = false;
    }
  }
  
  async createBackup() {
    try {
      const backupDir = path.join(this.appPath, 'backups');
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const backupPath = path.join(backupDir, `backup-${timestamp}`);
      
      // Create backup directory
      if (!fs.existsSync(backupDir)) {
        fs.mkdirSync(backupDir, { recursive: true });
      }
      
      // Copy current application files
      await this.copyDirectory(this.appPath, backupPath, ['node_modules', 'backups', '.git', 'data']);
      
      return { success: true, backupPath };
      
    } catch (error) {
      console.error('Backup creation error:', error);
      return { success: false, error: error.message };
    }
  }
  
  async copyDirectory(src, dest, exclude = []) {
    return new Promise((resolve, reject) => {
      const excludePattern = exclude.length > 0 ? `--exclude={${exclude.join(',')}}` : '';
      const command = `cp -r ${excludePattern} ${src}/* ${dest}/`;
      
      // Create destination directory
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
      }
      
      exec(command, (error, stdout, stderr) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }
  
  async checkPackageJsonChanged() {
    try {
      const git = simpleGit(this.appPath);
      const diff = await git.diff(['HEAD~1', 'HEAD', '--name-only']);
      return diff.includes('package.json');
    } catch (error) {
      console.error('Package.json check error:', error);
      return false;
    }
  }
  
  async updateDependencies() {
    return new Promise((resolve, reject) => {
      exec('npm install --production', { cwd: this.appPath }, (error, stdout, stderr) => {
        if (error) {
          reject(error);
        } else {
          resolve(stdout);
        }
      });
    });
  }
  
  async rollback() {
    try {
      const git = simpleGit(this.appPath);
      await git.reset(['--hard', 'HEAD~1']);
      await logMessage('info', 'Rollback completed');
      return true;
    } catch (error) {
      console.error('Rollback error:', error);
      throw error;
    }
  }
  
  async checkForImageUpdates() {
    try {
      const githubRepo = await getConfig('github_repo');
      const githubBranch = await getConfig('github_branch') || 'main';
      
      if (!githubRepo) {
        return { status: 'no_repo_configured' };
      }
      
      // Check for releases or tags that might indicate new images
      const git = simpleGit(this.appPath);
      
      // Check if git repository exists
      const isRepo = await git.checkIsRepo();
      if (!isRepo) {
        return { status: 'no_repo_configured' };
      }
      
      // Fetch latest tags and releases
      await git.fetch(['--tags']);
      
      // Get all tags
      const tags = await git.tags();
      const latestTag = tags.latest;
      
      // Get current version from package.json or a version file
      const currentVersion = await this.getCurrentImageVersion();
      
      // Check if there's a newer version available
      if (latestTag && this.compareVersions(latestTag, currentVersion) > 0) {
        this.availableImageUpdate = {
          current_version: currentVersion,
          latest_version: latestTag,
          check_time: new Date().toISOString(),
          status: 'available'
        };
        
        await logMessage('info', `New image version available: ${latestTag} (current: ${currentVersion})`);
        
        return {
          status: 'image_update_available',
          current_version: currentVersion,
          latest_version: latestTag,
          update_info: this.availableImageUpdate
        };
      }
      
      this.availableImageUpdate = null;
      this.lastImageCheck = new Date().toISOString();
      
      return {
        status: 'image_up_to_date',
        current_version: currentVersion,
        last_check: this.lastImageCheck
      };
      
    } catch (error) {
      console.error('Image update check error:', error);
      await logMessage('error', `Image update check failed: ${error.message}`);
      return { status: 'error', error: error.message };
    }
  }
  
  async getCurrentImageVersion() {
    try {
      // Try to read version from package.json
      const packagePath = path.join(this.appPath, 'package.json');
      if (fs.existsSync(packagePath)) {
        const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
        if (packageJson.version) {
          return packageJson.version;
        }
      }
      
      // Try to read from a VERSION file
      const versionPath = path.join(this.appPath, 'VERSION');
      if (fs.existsSync(versionPath)) {
        return fs.readFileSync(versionPath, 'utf8').trim();
      }
      
      // Try to get from git tag
      const git = simpleGit(this.appPath);
      try {
        const currentTag = await git.raw(['describe', '--tags', '--exact-match', 'HEAD']);
        return currentTag.trim();
      } catch (e) {
        // No exact tag match, use commit hash
        const commit = await git.revparse(['HEAD']);
        return commit.substring(0, 7);
      }
      
    } catch (error) {
      console.error('Error getting current version:', error);
      return 'unknown';
    }
  }
  
  compareVersions(version1, version2) {
    // Simple version comparison (supports semantic versioning)
    const v1parts = version1.replace(/^v/, '').split('.').map(n => parseInt(n) || 0);
    const v2parts = version2.replace(/^v/, '').split('.').map(n => parseInt(n) || 0);
    
    const maxLength = Math.max(v1parts.length, v2parts.length);
    
    for (let i = 0; i < maxLength; i++) {
      const v1part = v1parts[i] || 0;
      const v2part = v2parts[i] || 0;
      
      if (v1part > v2part) return 1;
      if (v1part < v2part) return -1;
    }
    
    return 0;
  }
  
  getAvailableImageUpdate() {
    return this.availableImageUpdate;
  }
  
  async startUpdateScheduler() {
    const updateInterval = parseInt(await getConfig('update_interval')) || 120; // Default 2 minutes
    
    console.log(`Starting update scheduler with ${updateInterval} second interval`);
    
    setInterval(async () => {
      try {
        await this.checkForUpdates();
        // Also check for image updates every 4th check (approximately every 8 minutes)
        if (Math.random() < 0.25) {
          await this.checkForImageUpdates();
        }
      } catch (error) {
        console.error('Scheduled update check error:', error);
      }
    }, updateInterval * 1000);
    
    // Initial check after 30 seconds
    setTimeout(async () => {
      try {
        await this.checkForUpdates();
        await this.checkForImageUpdates();
      } catch (error) {
        console.error('Initial update check error:', error);
      }
    }, 30000);
  }
}

module.exports = new UpdaterService();
