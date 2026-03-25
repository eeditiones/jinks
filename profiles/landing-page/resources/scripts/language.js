window.addEventListener('DOMContentLoaded', () => {
    pbEvents.subscribe('pb-i18n-language', null, (ev) => {
        const { language } = ev.detail;
        window.location.href = `?lang=${language}`;
    });

    // at initialization time, compare the language retrieved from parameters and context with what is reported
    // by i18n. Reload the page if they differ.
    let languageDefault;
    const languageDefaultEl = document.getElementById('language-default');
    if (languageDefaultEl?.textContent?.trim()) {
        try {
            languageDefault = JSON.parse(languageDefaultEl.textContent).language;
        } catch {
            /* missing or invalid JSON */
        }
    }
    if (!languageDefault) {
        return;
    }
    pbEvents.subscribe('pb-page-ready', null, (ev) => {
        const { language } = ev.detail;
        if (language && language !== languageDefault) {
            window.location.href = `?lang=${language}`;
        }
    });
});