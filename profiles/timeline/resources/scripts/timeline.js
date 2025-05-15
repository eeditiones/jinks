window.addEventListener("DOMContentLoaded", () => {
    const facets = document.getElementById('timeline-options');
    const timelineChanged = (ev) => {
        let categories = ev.detail.categories;
        if (ev.detail.scope === '5Y') {
            expandDates(categories, 5);
        } else if (ev.detail.scope === '10Y') {
            expandDates(categories, 10);
        }
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = categories.join(';') });
        facets.submit();
    };
    pbEvents.subscribe('pb-timeline-date-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-daterange-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-reset-selection', 'timeline', () => {
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = '' });
        facets.submit();
    });

    pbEvents.subscribe('pb-update', 'transcription', (ev) => {
        const timeline = document.querySelector('pb-timeline');
        const url = timeline.url;
        timeline.url = url.replace(/[^/]+$/, ev.detail.data.doc);
        pbEvents.emit('pb-results-received', 'corresp-timeline');
    });
});

function expandDates(categories, n) {
    categories.forEach((category) => {
        const year = parseInt(category);
        for (let i = 1; i < n; i++) {
            categories.push(year + i);
        }
    });
}
