(() => {
  'use strict';

  const table = document.querySelector('#browser-stats');
  if (!table) return;

  const values = {};
  const unavailable = 'Unavailable';
  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  const media = (query) => window.matchMedia && window.matchMedia(query).matches;
  const formatBytes = (bytes) => {
    if (!Number.isFinite(bytes)) return unavailable;
    const units = ['B', 'KiB', 'MiB', 'GiB'];
    let value = bytes;
    let unit = units.shift();
    while (value >= 1024 && units.length) {
      value /= 1024;
      unit = units.shift();
    }
    return `${value >= 10 || unit === 'B' ? value.toFixed(0) : value.toFixed(1)} ${unit}`;
  };
  const set = (key, value) => {
    const output = value === undefined || value === null || value === '' ? unavailable : String(value);
    values[key] = output;
    const cell = table.querySelector(`[data-stat="${key}"]`);
    if (cell) cell.textContent = output;
  };

  const updateDynamicValues = () => {
    const computedTheme = getComputedStyle(document.documentElement).colorScheme;
    const themeSetting = document.documentElement.getAttribute('data-mode');
    set('url', window.location.href);
    set('referrer', document.referrer || 'Direct navigation');
    set('localTime', new Intl.DateTimeFormat(undefined, { dateStyle: 'full', timeStyle: 'long' }).format(new Date()));
    set('timezone', Intl.DateTimeFormat().resolvedOptions().timeZone);
    set('language', `${navigator.language}${navigator.languages?.length > 1 ? ` (${navigator.languages.join(', ')})` : ''}`);
    set('viewport', `${window.innerWidth} × ${window.innerHeight} CSS pixels`);
    set('screen', `${window.screen.width} × ${window.screen.height} CSS pixels · ${window.screen.colorDepth}-bit colour`);
    set('pixelRatio', window.devicePixelRatio);
    set('colorPreferences', `${media('(prefers-color-scheme: dark)') ? 'prefers dark' : 'prefers light'} · ${media('(prefers-contrast: more)') ? 'more contrast' : 'standard contrast'} · ${media('(prefers-reduced-motion: reduce)') ? 'reduced motion' : 'standard motion'}`);
    set('theme', themeSetting || computedTheme || 'system preference');
    set('online', navigator.onLine ? 'Yes' : 'No');
  };

  updateDynamicValues();
  set('network', connection ? [connection.effectiveType, connection.downlink ? `${connection.downlink} Mb/s estimated` : null, connection.rtt ? `${connection.rtt} ms RTT` : null, connection.saveData ? 'data saver on' : null].filter(Boolean).join(' · ') : unavailable);
  set('cookies', navigator.cookieEnabled ? 'Enabled' : 'Disabled');
  set('doNotTrack', navigator.doNotTrack === '1' ? 'Enabled' : navigator.doNotTrack === '0' ? 'Disabled' : 'Unspecified');
  set('processors', navigator.hardwareConcurrency);
  set('memory', navigator.deviceMemory ? `${navigator.deviceMemory} GiB (approximate)` : unavailable);
  set('touch', navigator.maxTouchPoints ? `${navigator.maxTouchPoints} simultaneous touch point(s)` : 'Not reported');
  set('userAgent', navigator.userAgent);

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistration()
      .then((registration) => set('serviceWorker', registration ? `${registration.active ? 'Active' : 'Registered'} · scope ${registration.scope}` : 'Supported, not registered for this page'))
      .catch(() => set('serviceWorker', 'Supported, status unavailable'));
  } else {
    set('serviceWorker', 'Not supported');
  }

  if (navigator.storage?.estimate) {
    navigator.storage.estimate()
      .then(({ usage, quota }) => set('storage', `${formatBytes(usage)} used of ${formatBytes(quota)} available to this origin`))
      .catch(() => set('storage', unavailable));
  } else {
    set('storage', unavailable);
  }

  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(updateDynamicValues, 100);
  });
  window.addEventListener('online', updateDynamicValues);
  window.addEventListener('offline', updateDynamicValues);
  new MutationObserver(updateDynamicValues).observe(document.documentElement, { attributes: true, attributeFilter: ['data-mode'] });

  document.querySelector('#copy-site-diagnostics')?.addEventListener('click', async () => {
    updateDynamicValues();
    const status = document.querySelector('#copy-site-diagnostics-status');
    const generated = document.querySelector('.site-stats')?.dataset.generatedAt || unavailable;
    const output = ['Site diagnostics', `Generated: ${generated}`, `Captured: ${new Date().toISOString()}`];
    document.querySelectorAll('[data-diagnostics-section]').forEach((section) => {
      output.push('', section.dataset.diagnosticsSection);
      section.querySelectorAll('tbody tr').forEach((row) => {
        output.push(`${row.querySelector('th')?.textContent.trim()}: ${row.querySelector('td')?.textContent.trim()}`);
      });
    });

    try {
      await navigator.clipboard.writeText(output.join('\n'));
      status.textContent = 'Diagnostics copied.';
    } catch (_error) {
      status.textContent = 'Copy was blocked by the browser.';
    }
  });
})();
