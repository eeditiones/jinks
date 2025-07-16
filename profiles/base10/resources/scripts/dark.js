document.addEventListener('DOMContentLoaded', function() {
    const modeSwitch = document.getElementById('colorMode');
    if (modeSwitch) {
        modeSwitch.addEventListener('click', function() {
            let theme = document.body.dataset.theme || localStorage.getItem('tp.theme');
            const newTheme = theme === 'dark' ? 'light' : 'dark';
            document.body.dataset.theme = newTheme;
            localStorage.setItem('tp.theme', newTheme);
            modeSwitch.classList.toggle('theme-toggle--toggled');
        });
    }

    let theme = document.body.dataset.theme || localStorage.getItem('tp.theme');
    if (theme) {
        document.body.dataset.theme = theme;
        localStorage.setItem('tp.theme', theme);
        modeSwitch.classList.toggle('theme-toggle--toggled', theme === 'dark');
    }

    const asideToggles = document.querySelectorAll('.aside-toggle');
    asideToggles.forEach(toggle => {
        toggle.addEventListener('click', function() {
            const target = this.dataset.toggle;
            const targetElement = document.querySelector(target);
            targetElement.classList.toggle('hidden');
            this.closest('.top-left,.top-right').classList.toggle('hidden');
        });
    });
});