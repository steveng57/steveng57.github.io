// Contact form handling with Turnstile integration
document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('contact-form');
    
    if (form) {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            
            // Check if Turnstile response exists
            const turnstileResponse = document.querySelector('input[name="cf-turnstile-response"]');
            
            if (!turnstileResponse || !turnstileResponse.value) {
                alert('Please complete the security verification.');
                return;
            }
            
            // Show loading state
            const submitButton = form.querySelector('button[type="submit"]');
            const originalText = submitButton.textContent;
            submitButton.textContent = 'Sending...';
            submitButton.disabled = true;
            
            // Submit the form
            const formData = new FormData(form);
            
            fetch(form.action, {
                method: 'POST',
                body: formData
            })
            .then(response => {
                if (response.ok) {
                    // Redirect to success page
                    window.location.href = '/contact/sent';
                } else {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
            })
            .catch(error => {
                console.error('Form submission error:', error);
                alert('There was an error sending your message. Please try again.');
                
                // Reset button state
                submitButton.textContent = originalText;
                submitButton.disabled = false;
            });
        });
    }
});

// Turnstile callback functions
window.onTurnstileLoad = function() {
    console.log('Turnstile loaded successfully');
};

window.onTurnstileError = function() {
    console.error('Turnstile failed to load');
    alert('Security verification failed to load. Please refresh the page and try again.');
};