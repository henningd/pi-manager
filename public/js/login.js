// Login functionality
class LoginManager {
    constructor() {
        this.init();
    }
    
    init() {
        // Check if already logged in
        const token = localStorage.getItem('pi_manager_token');
        if (token) {
            this.verifyToken(token);
        }
        
        // Setup form handler
        const loginForm = document.getElementById('login-form');
        if (loginForm) {
            loginForm.addEventListener('submit', this.handleLogin.bind(this));
        }
    }
    
    async verifyToken(token) {
        try {
            const response = await fetch('/auth/verify', {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (response.ok) {
                // Token is valid, redirect to dashboard
                window.location.href = '/';
            } else {
                // Token is invalid, remove it
                localStorage.removeItem('pi_manager_token');
            }
        } catch (error) {
            console.error('Token verification error:', error);
            localStorage.removeItem('pi_manager_token');
        }
    }
    
    async handleLogin(event) {
        event.preventDefault();
        
        const formData = new FormData(event.target);
        const credentials = {
            username: formData.get('username'),
            password: formData.get('password')
        };
        
        const submitButton = event.target.querySelector('button[type="submit"]');
        const errorDiv = document.getElementById('login-error');
        
        // Show loading state
        submitButton.disabled = true;
        submitButton.textContent = 'Anmelden...';
        errorDiv.style.display = 'none';
        
        try {
            const response = await fetch('/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(credentials)
            });
            
            const data = await response.json();
            
            if (response.ok && data.success) {
                // Store token and redirect
                localStorage.setItem('pi_manager_token', data.token);
                this.showToast('Erfolgreich angemeldet!', 'success');
                
                setTimeout(() => {
                    window.location.href = '/';
                }, 1000);
            } else {
                // Show error
                errorDiv.textContent = data.error || 'Anmeldung fehlgeschlagen';
                errorDiv.style.display = 'block';
                this.showToast('Anmeldung fehlgeschlagen', 'error');
            }
        } catch (error) {
            console.error('Login error:', error);
            errorDiv.textContent = 'Verbindungsfehler. Bitte versuchen Sie es erneut.';
            errorDiv.style.display = 'block';
            this.showToast('Verbindungsfehler', 'error');
        } finally {
            // Reset button state
            submitButton.disabled = false;
            submitButton.textContent = 'Anmelden';
        }
    }
    
    showToast(message, type = 'info') {
        const toastContainer = document.getElementById('toast-container');
        if (!toastContainer) return;
        
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        toastContainer.appendChild(toast);
        
        // Auto remove after 3 seconds
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 3000);
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new LoginManager();
});
