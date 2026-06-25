// Minimal i18n loader: fetches JSON and replaces elements with data-i18n attributes
(function () {
  async function loadLang(lang) {
    try {
      const res = await fetch(`/i18n/${lang}.json`);
      if (!res.ok) throw new Error('not found');
      return await res.json();
    } catch (e) {
      const res = await fetch('/i18n/fr.json');
      return await res.json();
    }
  }

  function applyTranslations(translations) {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (!key) return;
      const val = translations[key];
      if (val !== undefined) el.textContent = val;
    });
  }

  async function init() {
    const stored = localStorage.getItem('lang');
    const preferred = stored || navigator.language.split('-')[0] || 'fr';
    const translations = await loadLang(preferred);
    applyTranslations(translations);
  }

  window.__i18n_init = init;
})();
