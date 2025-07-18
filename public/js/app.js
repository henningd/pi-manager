// Main dashboard application
class PiManagerApp {
    constructor() {
        this.token = localStorage.getItem('pi_manager_token');
        this.socket = null;
        this.config = {};
        
        this.init();
    }
    
    async init() {
        // Check authentication
        if (!this.token) {
            window.location.href = '/login.html';
            return;
        }
        
        try {
            await this.verifyAuth();
            await this.loadConfig();
            this.setupEventListeners();
            this.setupWebSocket();
            this.loadSystemStatus();
            this.loadLogs();
            this.loadImageUpdateStatus();
        } catch (error) {
            console.error('Initialization error:', error);
            this.logout();
        }
    }
    
    async verifyAuth() {
        const response = await fetch('/auth/verify', {
            headers: {
                'Authorization': `Bearer ${this.token}`
            }
        });
        
        if (!response.ok) {
            throw new Error('Authentication failed');
        }
        
        const data = await response.json();
        document.getElementById('username').textContent = data.user.username;
    }
    
    async loadConfig() {
        try {
            const response = await this.apiCall('/api/config');
            this.config = response;
            this.populateConfigForms();
        } catch (error) {
            console.error('Config load error:', error);
            this.showToast('Fehler beim Laden der Konfiguration', 'error');
        }
    }
    
    populateConfigForms() {
        // General form
        document.getElementById('device-name').value = this.config.device_name || '';
        
        // Notifications form
        document.getElementById('notification-url').value = this.config.notification_url || '';
        
        // Updates form
        document.getElementById('github-repo').value = this.config.github_repo || '';
        document.getElementById('github-branch').value = this.config.github_branch || 'main';
        document.getElementById('update-interval').value = this.config.update_interval || '120';
        document.getElementById('auto-update').checked = this.config.auto_update_enabled === 'true';
    }
    
    setupEventListeners() {
        // Logout button
        document.getElementById('logout-btn').addEventListener('click', () => {
            this.logout();
        });
        
        // Control buttons
        document.getElementById('reboot-btn').addEventListener('click', () => {
            this.showConfirmModal('System Neustart', 'Möchten Sie das System wirklich neu starten?', () => {
                this.rebootSystem();
            });
        });
        
        document.getElementById('shutdown-btn').addEventListener('click', () => {
            this.showConfirmModal('System Herunterfahren', 'Möchten Sie das System wirklich herunterfahren?', () => {
                this.shutdownSystem();
            });
        });
        
        document.getElementById('test-notification-btn').addEventListener('click', () => {
            this.testNotification();
        });
        
        document.getElementById('update-check-btn').addEventListener('click', () => {
            this.checkForUpdates();
        });
        
        document.getElementById('image-update-check-btn').addEventListener('click', () => {
            this.checkForImageUpdates();
        });
        
        // Tab switching
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchTab(e.target.dataset.tab);
            });
        });
        
        // Configuration forms
        document.getElementById('general-form').addEventListener('submit', (e) => {
            this.handleConfigSubmit(e, 'general');
        });
        
        document.getElementById('notifications-form').addEventListener('submit', (e) => {
            this.handleConfigSubmit(e, 'notifications');
        });
        
        document.getElementById('updates-form').addEventListener('submit', (e) => {
            this.handleConfigSubmit(e, 'updates');
        });
        
        document.getElementById('password-form').addEventListener('submit', (e) => {
            this.handlePasswordChange(e);
        });
        
        // Logs controls
        document.getElementById('refresh-logs-btn').addEventListener('click', () => {
            this.loadLogs();
        });
        
        document.getElementById('log-limit').addEventListener('change', () => {
            this.loadLogs();
        });
        
        // Modal controls
        document.getElementById('modal-cancel').addEventListener('click', () => {
            this.hideModal();
        });
    }
    
    setupWebSocket() {
        this.socket = io();
        
        this.socket.on('connect', () => {
            console.log('WebSocket connected');
            this.socket.emit('requestStatus');
        });
        
        this.socket.on('disconnect', () => {
            console.log('WebSocket disconnected');
        });
        
        this.socket.on('statusUpdate', (status) => {
            this.updateStatusDisplay(status);
        });
        
        // Request status updates every 30 seconds
        setInterval(() => {
            if (this.socket.connected) {
                this.socket.emit('requestStatus');
            }
        }, 30000);
    }
    
    async loadSystemStatus() {
        try {
            const status = await this.apiCall('/api/status');
            this.updateStatusDisplay(status);
            
            // Load additional info
            const [temperature, diskUsage, networkInfo] = await Promise.all([
                this.apiCall('/api/temperature').catch(() => null),
                this.apiCall('/api/disk-usage').catch(() => null),
                this.apiCall('/api/network').catch(() => null)
            ]);
            
            if (temperature) {
                document.getElementById('temperature').textContent = `${temperature.celsius.toFixed(1)} °C`;
                document.getElementById('temp-status').textContent = 
                    temperature.celsius > 70 ? 'Hoch' : temperature.celsius > 60 ? 'Warm' : 'Normal';
            }
            
        } catch (error) {
            console.error('Status load error:', error);
            this.showToast('Fehler beim Laden des System-Status', 'error');
        }
    }
    
    updateStatusDisplay(status) {
        // Uptime
        const uptimeHours = Math.floor(status.uptime / 3600);
        const uptimeMinutes = Math.floor((status.uptime % 3600) / 60);
        document.getElementById('uptime').textContent = `Uptime: ${uptimeHours}h ${uptimeMinutes}m`;
        
        // CPU info
        if (status.cpu && status.cpu.length > 0) {
            document.getElementById('cpu-info').textContent = `${status.cpu.length} Cores`;
        }
        
        // CPU load
        if (status.loadavg) {
            document.getElementById('cpu-load').textContent = `Load: ${status.loadavg[0].toFixed(2)}`;
        }
        
        // Memory
        if (status.memory) {
            const memoryUsedGB = (status.memory.used / (1024 * 1024 * 1024)).toFixed(1);
            const memoryTotalGB = (status.memory.total / (1024 * 1024 * 1024)).toFixed(1);
            const memoryPercent = ((status.memory.used / status.memory.total) * 100).toFixed(1);
            
            document.getElementById('memory-usage').textContent = `${memoryUsedGB} GB / ${memoryTotalGB} GB (${memoryPercent}%)`;
            document.getElementById('memory-progress').style.width = `${memoryPercent}%`;
            
            // Change color based on usage
            const progressBar = document.getElementById('memory-progress');
            if (memoryPercent > 90) {
                progressBar.style.backgroundColor = '#dc3545';
            } else if (memoryPercent > 80) {
                progressBar.style.backgroundColor = '#ffc107';
            } else {
                progressBar.style.backgroundColor = '#007bff';
            }
        }
    }
    
    async loadLogs() {
        try {
            const limit = document.getElementById('log-limit').value;
            const logs = await this.apiCall(`/api/logs?limit=${limit}`);
            
            const logsContainer = document.getElementById('logs-container');
            logsContainer.innerHTML = '';
            
            if (logs.length === 0) {
                logsContainer.innerHTML = '<div class="loading">Keine Logs verfügbar</div>';
                return;
            }
            
            logs.forEach(log => {
                const logEntry = document.createElement('div');
                logEntry.className = `log-entry ${log.level}`;
                
                const timestamp = new Date(log.timestamp).toLocaleString('de-DE');
                logEntry.innerHTML = `<strong>[${timestamp}]</strong> [${log.level.toUpperCase()}] ${log.message}`;
                
                logsContainer.appendChild(logEntry);
            });
            
        } catch (error) {
            console.error('Logs load error:', error);
            document.getElementById('logs-container').innerHTML = 
                '<div class="loading">Fehler beim Laden der Logs</div>';
        }
    }
    
    switchTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
        
        // Update tab panes
        document.querySelectorAll('.tab-pane').forEach(pane => {
            pane.classList.remove('active');
        });
        document.getElementById(`${tabName}-tab`).classList.add('active');
    }
    
    async handleConfigSubmit(event, formType) {
        event.preventDefault();
        
        const formData = new FormData(event.target);
        const config = {};
        
        for (const [key, value] of formData.entries()) {
            if (key === 'auto_update_enabled') {
                config[key] = document.getElementById('auto-update').checked ? 'true' : 'false';
            } else {
                config[key] = value;
            }
        }
        
        try {
            await this.apiCall('/api/config', 'POST', config);
            this.showToast('Konfiguration gespeichert', 'success');
            await this.loadConfig(); // Reload config
        } catch (error) {
            console.error('Config save error:', error);
            this.showToast('Fehler beim Speichern der Konfiguration', 'error');
        }
    }
    
    async handlePasswordChange(event) {
        event.preventDefault();
        
        const formData = new FormData(event.target);
        const oldPassword = formData.get('current-password');
        const newPassword = formData.get('new-password');
        const confirmPassword = formData.get('confirm-password');
        
        if (newPassword !== confirmPassword) {
            this.showToast('Passwörter stimmen nicht überein', 'error');
            return;
        }
        
        if (newPassword.length < 6) {
            this.showToast('Passwort muss mindestens 6 Zeichen lang sein', 'error');
            return;
        }
        
        try {
            await this.apiCall('/auth/change-password', 'POST', {
                oldPassword,
                newPassword
            });
            
            this.showToast('Passwort erfolgreich geändert', 'success');
            event.target.reset();
        } catch (error) {
            console.error('Password change error:', error);
            this.showToast('Fehler beim Ändern des Passworts', 'error');
        }
    }
    
    async rebootSystem() {
        try {
            await this.apiCall('/api/reboot', 'POST');
            this.showToast('System wird neu gestartet...', 'info');
        } catch (error) {
            console.error('Reboot error:', error);
            this.showToast('Fehler beim Neustart', 'error');
        }
    }
    
    async shutdownSystem() {
        try {
            await this.apiCall('/api/shutdown', 'POST');
            this.showToast('System wird heruntergefahren...', 'info');
        } catch (error) {
            console.error('Shutdown error:', error);
            this.showToast('Fehler beim Herunterfahren', 'error');
        }
    }
    
    async testNotification() {
        try {
            await this.apiCall('/api/test-notification', 'POST', {
                message: 'Test-Benachrichtigung vom Pi Manager'
            });
            this.showToast('Test-Benachrichtigung gesendet', 'success');
        } catch (error) {
            console.error('Test notification error:', error);
            this.showToast('Fehler beim Senden der Test-Benachrichtigung', 'error');
        }
    }
    
    async checkForUpdates() {
        try {
            const result = await this.apiCall('/api/update-check', 'POST');
            
            if (result.result.status === 'up_to_date') {
                this.showToast('System ist auf dem neuesten Stand', 'success');
            } else if (result.result.status === 'updates_available') {
                this.showToast('Updates verfügbar', 'info');
            } else if (result.result.status === 'no_repo_configured') {
                this.showToast('Kein GitHub Repository konfiguriert', 'warning');
            } else {
                this.showToast('Update-Prüfung abgeschlossen', 'info');
            }
        } catch (error) {
            console.error('Update check error:', error);
            this.showToast('Fehler bei der Update-Prüfung', 'error');
        }
    }
    
    async checkForImageUpdates() {
        try {
            const result = await this.apiCall('/api/image-update-check', 'POST');
            
            if (result.result.status === 'image_update_available') {
                this.showToast(`Neues Image verfügbar: ${result.result.latest_version}`, 'warning');
                this.showImageUpdateNotification(result.result);
            } else if (result.result.status === 'image_up_to_date') {
                this.showToast('Image ist auf dem neuesten Stand', 'success');
                this.hideImageUpdateNotification();
            } else if (result.result.status === 'no_repo_configured') {
                this.showToast('Kein GitHub Repository konfiguriert', 'warning');
            } else {
                this.showToast('Image-Update-Prüfung abgeschlossen', 'info');
            }
        } catch (error) {
            console.error('Image update check error:', error);
            this.showToast('Fehler bei der Image-Update-Prüfung', 'error');
        }
    }
    
    showImageUpdateNotification(updateInfo) {
        const updateCard = document.getElementById('image-update-card');
        const updateStatus = document.getElementById('image-update-status');
        const updateInfoElement = document.getElementById('image-update-info');
        
        updateCard.style.display = 'block';
        updateStatus.textContent = 'Update verfügbar';
        updateStatus.className = 'status-indicator warning';
        updateInfoElement.textContent = `${updateInfo.current_version} → ${updateInfo.latest_version}`;
    }
    
    hideImageUpdateNotification() {
        const updateCard = document.getElementById('image-update-card');
        updateCard.style.display = 'none';
    }
    
    async loadImageUpdateStatus() {
        try {
            const result = await this.apiCall('/api/image-update-status');
            
            if (result.has_update && result.update_info) {
                this.showImageUpdateNotification(result.update_info);
            } else {
                this.hideImageUpdateNotification();
            }
        } catch (error) {
            console.error('Image update status error:', error);
        }
    }
    
    showConfirmModal(title, message, onConfirm) {
        document.getElementById('modal-title').textContent = title;
        document.getElementById('modal-message').textContent = message;
        document.getElementById('modal').style.display = 'block';
        
        // Remove existing event listeners
        const confirmBtn = document.getElementById('modal-confirm');
        const newConfirmBtn = confirmBtn.cloneNode(true);
        confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
        
        // Add new event listener
        newConfirmBtn.addEventListener('click', () => {
            this.hideModal();
            onConfirm();
        });
    }
    
    hideModal() {
        document.getElementById('modal').style.display = 'none';
    }
    
    async apiCall(endpoint, method = 'GET', data = null) {
        const options = {
            method,
            headers: {
                'Authorization': `Bearer ${this.token}`,
                'Content-Type': 'application/json'
            }
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }
        
        const response = await fetch(endpoint, options);
        
        if (response.status === 401) {
            this.logout();
            throw new Error('Unauthorized');
        }
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error || 'API call failed');
        }
        
        return response.json();
    }
    
    logout() {
        localStorage.removeItem('pi_manager_token');
        window.location.href = '/login.html';
    }
    
    showToast(message, type = 'info') {
        const toastContainer = document.getElementById('toast-container');
        if (!toastContainer) return;
        
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        toastContainer.appendChild(toast);
        
        // Auto remove after 4 seconds
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 4000);
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new PiManagerApp();
});
