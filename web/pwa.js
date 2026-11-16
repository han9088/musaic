// Only the production PWA build includes this script.
window.addEventListener('load', () => {
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;
  navigator.serviceWorker.register(new URL('service-worker.js', document.baseURI), {
    updateViaCache: 'none',
  }).catch(error => console.warn('Musaic offline setup failed:', error));
});
