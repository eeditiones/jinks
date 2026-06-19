(() => {
    const supportsPopover = typeof HTMLElement.prototype.showPopover === 'function';
    const supportsInterest = 'interestForElement' in HTMLButtonElement.prototype;
    const supportsAnchor = typeof CSS !== 'undefined'
        && CSS.supports('top', 'anchor(bottom)');

    function positionPanel(trigger, panel) {
        const rect = trigger.getBoundingClientRect();
        const gap = 6;
        const margin = 8;

        panel.style.setProperty('position', 'fixed');
        panel.style.setProperty('inset', 'auto');
        panel.style.setProperty('margin', '0');

        const panelRect = panel.getBoundingClientRect();
        let top = rect.bottom + gap;
        let left = rect.left;

        if (left + panelRect.width > window.innerWidth - margin) {
            left = Math.max(margin, window.innerWidth - panelRect.width - margin);
        }
        if (left < margin) {
            left = margin;
        }

        if (top + panelRect.height > window.innerHeight - margin) {
            top = rect.top - panelRect.height - gap;
        }
        if (top < margin) {
            top = margin;
        }

        panel.style.top = `${top}px`;
        panel.style.left = `${left}px`;
    }

    function bindViewportSync(trigger, panel) {
        const sync = () => {
            if (panel.matches(':popover-open')) {
                positionPanel(trigger, panel);
            }
        };
        window.addEventListener('scroll', sync, true);
        window.addEventListener('resize', sync);
    }

    function initHintWrap(wrap) {
        if (wrap.dataset.hintInit) {
            return;
        }
        wrap.dataset.hintInit = 'true';

        const trigger = wrap.querySelector('.hint-trigger');
        const panel = wrap.querySelector('.form-hint');
        if (!trigger || !panel) {
            return;
        }

        if (!panel.id) {
            panel.id = `form-hint-${crypto.randomUUID()}`;
        }

        if (!panel.hasAttribute('popover')) {
            panel.setAttribute('popover', 'manual');
        }

        if (supportsAnchor) {
            const anchorName = `--${panel.id}`;
            trigger.style.setProperty('anchor-name', anchorName);
            panel.style.setProperty('position-anchor', anchorName);
            panel.classList.add('form-hint-anchored');
        }

        panel.addEventListener('toggle', (event) => {
            if (event.newState === 'open') {
                positionPanel(trigger, panel);
            }
        });

        bindViewportSync(trigger, panel);

        if (supportsInterest && trigger.matches('button.hint-trigger:not(.hint-trigger--passive)')) {
            trigger.setAttribute('interestfor', panel.id);
            return;
        }

        if (!supportsPopover) {
            wrap.classList.add('form-hint-css');
            return;
        }

        let hideTimer = null;

        const show = () => {
            clearTimeout(hideTimer);
            if (!panel.matches(':popover-open')) {
                try {
                    panel.showPopover();
                } catch (err) {
                    wrap.classList.add('form-hint-css');
                    return;
                }
            }
            positionPanel(trigger, panel);
        };

        const scheduleHide = () => {
            clearTimeout(hideTimer);
            hideTimer = setTimeout(() => {
                if (panel.matches(':popover-open')) {
                    try {
                        panel.hidePopover();
                    } catch (err) {
                        /* ignore */
                    }
                }
            }, 150);
        };

        const containsFocus = () => wrap.matches(':focus-within') || panel.matches(':focus-within');

        trigger.addEventListener('mouseenter', show);
        trigger.addEventListener('focusin', show);
        trigger.addEventListener('mouseleave', () => {
            if (!containsFocus()) {
                scheduleHide();
            }
        });
        trigger.addEventListener('focusout', (event) => {
            if (!wrap.contains(event.relatedTarget)) {
                scheduleHide();
            }
        });
        panel.addEventListener('mouseenter', show);
        panel.addEventListener('mouseleave', scheduleHide);
        panel.addEventListener('focusin', show);
        panel.addEventListener('focusout', (event) => {
            if (!wrap.contains(event.relatedTarget)) {
                scheduleHide();
            }
        });

        trigger.addEventListener('click', (event) => {
            if (trigger.closest('summary')) {
                event.stopPropagation();
            }
        });
    }

    function init(root = document) {
        root.querySelectorAll('.form-hint-wrap').forEach(initHintWrap);
    }

    function onReady() {
        init();
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType !== 1) {
                        return;
                    }
                    if (node.matches?.('.form-hint-wrap')) {
                        initHintWrap(node);
                    }
                    init(node);
                });
            });
        });
        observer.observe(document.body, { childList: true, subtree: true });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', onReady);
    } else {
        onReady();
    }
})();
