---
layout: page
title: Turnstile Test
---

<style>
.test-section {
  border: 1px solid #ccc;
  padding: 20px;
  margin: 20px 0;
  border-radius: 5px;
}
.success { border-color: #28a745; background-color: #d4edda; }
.error { border-color: #dc3545; background-color: #f8d7da; }
</style>

<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>

<div class="test-section">
  <h2>Turnstile Integration Test</h2>
  <p>This page helps debug Turnstile integration issues.</p>

  <h3>1. Check if Turnstile Library Loaded</h3>
  <div id="library-status">Checking...</div>

  <h3>2. Test Turnstile Widget</h3>
  <div class="cf-turnstile" 
       data-sitekey="0x4AAAAAAAzb3LZ_mtlKCzKM"
       data-callback="onTurnstileCallback"
       data-error-callback="onTurnstileError"></div>
  
  <div id="turnstile-status">Widget loading...</div>

  <h3>3. Current Environment</h3>
  <div id="env-info">
    <p><strong>Domain:</strong> <span id="current-domain"></span></p>
    <p><strong>Protocol:</strong> <span id="current-protocol"></span></p>
  </div>

  <h3>4. Test Form Submission</h3>
  <form id="test-form">
    <input type="email" placeholder="test@example.com" required>
    <textarea placeholder="Test message" required></textarea>
    <button type="submit">Test Submit</button>
  </form>
  <div id="form-status"></div>
</div>

<script>
// Check if Turnstile library loaded
window.addEventListener('load', function() {
  const libraryStatus = document.getElementById('library-status');
  const envInfo = document.getElementById('env-info');
  
  // Check library
  if (typeof window.turnstile !== 'undefined') {
    libraryStatus.innerHTML = '<span style="color: green;">✓ Turnstile library loaded successfully</span>';
  } else {
    libraryStatus.innerHTML = '<span style="color: red;">✗ Turnstile library failed to load</span>';
  }
  
  // Show environment info
  document.getElementById('current-domain').textContent = window.location.hostname;
  document.getElementById('current-protocol').textContent = window.location.protocol;
});

// Turnstile callbacks
window.onTurnstileCallback = function(token) {
  const status = document.getElementById('turnstile-status');
  status.innerHTML = '<span style="color: green;">✓ Turnstile verification successful</span>';
  console.log('Turnstile token:', token);
};

window.onTurnstileError = function(error) {
  const status = document.getElementById('turnstile-status');
  status.innerHTML = '<span style="color: red;">✗ Turnstile verification failed: ' + error + '</span>';
  console.error('Turnstile error:', error);
};

// Test form
document.getElementById('test-form').addEventListener('submit', function(e) {
  e.preventDefault();
  
  const formStatus = document.getElementById('form-status');
  const turnstileResponse = document.querySelector('input[name="cf-turnstile-response"]');
  
  if (!turnstileResponse || !turnstileResponse.value) {
    formStatus.innerHTML = '<span style="color: red;">✗ No Turnstile token found</span>';
    return;
  }
  
  formStatus.innerHTML = '<span style="color: green;">✓ Turnstile token ready for submission</span>';
  console.log('Turnstile token value:', turnstileResponse.value);
});
</script>