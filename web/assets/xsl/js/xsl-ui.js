// Dilshan X-UI initialization
document.addEventListener("DOMContentLoaded", function () {
  // Initialize scroll animations
  if (window.AOS) {
    AOS.init({
      duration: 450,
      once: true,
      offset: 40,
      easing: "ease-out-cubic"
    });
  }

  // Theme sync: detect existing theme and set data-theme attribute
  function syncTheme() {
    var bodyClass = document.body.className || '';
    var htmlClass = document.documentElement.className || '';
    var theme = 'dark'; // default
    
    if (bodyClass.includes('light') || htmlClass.includes('light')) {
      theme = 'light';
    } else if (bodyClass.includes('dark') || htmlClass.includes('dark')) {
      theme = 'dark';
    }
    
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('dx-theme', theme);
  }
  
  syncTheme();
  
  // Observe body class changes to keep theme synced
  var observer = new MutationObserver(function(mutations) {
    syncTheme();
  });
  observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });

  // Expose icon helper globally for inline HTML
  window.dxIcon = function (name, size) {
    return '<iconify-icon icon="' + name + '" width="' + (size || 18) + '"></iconify-icon>';
  };

  console.log("%c Dilshan X-UI loaded ", "background: linear-gradient(135deg, #00E5CC, #0090D9); color: #0A0E17; padding: 4px 12px; border-radius: 6px; font-weight: 700;");
});