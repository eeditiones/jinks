document.addEventListener('DOMContentLoaded', function () {
    const asideToggles = document.querySelectorAll('.aside-toggle');
    asideToggles.forEach(toggle => {
        toggle.addEventListener('click', function () {
            const target = this.dataset.toggle;
            const targetElement = document.querySelector(target);
            targetElement.classList.toggle('hidden');
            this.closest('.top-left,.top-right').classList.toggle('hidden');
        });
    });
});