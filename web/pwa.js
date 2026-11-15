// Only the production PWA build includes this script.
let installPrompt;
let installButton;
const installed = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone;
const removeInstallButton = () => {
  installPrompt = undefined;
  installButton?.remove();
  installButton = undefined;
};
window.addEventListener('beforeinstallprompt', event => {
  if (installed()) return;
  event.preventDefault();
  installPrompt = event;
  if (installButton) return;
  installButton = document.createElement('button');
  installButton.type = 'button';
  installButton.textContent = navigator.language.startsWith('zh') ? '安装 Musaic' : 'Install Musaic';
  installButton.style.cssText = 'position:fixed;top:max(16px,env(safe-area-inset-top));right:16px;z-index:10000;padding:10px 16px;border:1px solid #ffffff40;border-radius:24px;background:#202020;color:white;font:14px system-ui;cursor:pointer';
  installButton.addEventListener('click', async () => {
    const prompt = installPrompt;
    if (!prompt) return;
    // Consume this event before awaiting the browser; a new event owns its own button.
    removeInstallButton();
    try {
      await prompt.prompt();
      await prompt.userChoice;
    } catch (error) {
      console.warn('Musaic install prompt failed:', error);
    }
  });
  document.body.append(installButton);
});
window.addEventListener('appinstalled', removeInstallButton);
window.addEventListener('load', () => {
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;
  navigator.serviceWorker.register(new URL('service-worker.js', document.baseURI), {
    updateViaCache: 'none',
  }).catch(error => console.warn('Musaic offline setup failed:', error));
});
