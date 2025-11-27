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
            .then(async response => {
                if (response.ok) {
                    // Redirect to success page
                    window.location.href = '/contact/sent';
                } else {
                    // Try to get error message from response
                    let errorMsg = `HTTP ${response.status}: ${response.statusText}`;
                    try {
                        const text = await response.text();
                        if (text) {
                            // If it's HTML (like a 404 page), don't show the whole thing
                            if (text.trim().startsWith('<')) {
                                if (response.status === 404) {
                                    errorMsg = "Backend function not found (404).";
                                }
                            } else {
                                errorMsg = text;
                            }
                        }
                    } catch (e) {
                        console.error("Error reading response text:", e);
                    }
                    throw new Error(errorMsg);
                }
            })
            .catch(error => {
                console.error('Form submission error:', error);
                
                // Check if we are in a local development environment
                const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
                
                if (isLocal) {
                    console.warn('Local Development: Backend function not available. Simulating success.');
                    alert('Local Development: The backend function is not available locally. Simulating successful submission.');
                    window.location.href = '/contact/sent';
                    return;
                }

                alert(`Error sending message: ${error.message}`);
                
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