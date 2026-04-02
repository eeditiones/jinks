/** Primary language subtag only (e.g. en-US → en). */
function primaryLang(language) {
    if (!language || typeof language !== 'string') return language;
    return language.split('-')[0].toLowerCase();
}

/** Same URL with `lang` set; keeps path, other query params, and hash. */
function locationWithLang(lang) {
    const url = new URL(window.location.href);
    url.searchParams.set('lang', primaryLang(lang));
    return url.href;
}

window.addEventListener('DOMContentLoaded', () => {
    pbEvents.subscribe('pb-i18n-language', null, (ev) => {
        const { language } = ev.detail;
        window.location.href = locationWithLang(language);
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
        if (language && primaryLang(language) !== primaryLang(languageDefault)) {
            window.location.href = locationWithLang(language);
        }
    });
});