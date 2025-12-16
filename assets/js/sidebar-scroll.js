(function() {
  var sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  var STORAGE_KEY = 'sjg-sidebar-scroll-top';

  try {
    var saved = sessionStorage.getItem(STORAGE_KEY);
    if (saved !== null) {
      var y = parseInt(saved, 10);
      if (!isNaN(y)) {
        sidebar.scrollTop = y;
      }
    }
  } catch (e) {
    // sessionStorage might be unavailable; fail silently
  }

  function saveScroll() {
    try {
      sessionStorage.setItem(STORAGE_KEY, sidebar.scrollTop);
    } catch (e) {
      // Ignore storage errors
    }
  }

  sidebar.addEventListener('scroll', saveScroll, { passive: true });
  window.addEventListener('beforeunload', saveScroll);

  // Reveal the sidebar only after we have had a chance
  // to restore (or intentionally reset) its scroll position.
  sidebar.style.visibility = 'visible';
})();
