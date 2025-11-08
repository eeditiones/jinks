window.addEventListener('DOMContentLoaded', () => {
    let appConfig = {};
    let colorPalettes = {};

    let editor = document.getElementById('appConfig');
    const mergedView = document.getElementById('mergedConfig');
    const form = document.getElementById('config');
    const output = document.querySelector('.output');
    const errors = document.querySelector('.error');

    const spinner = document.getElementById('spinner');
    spinner.style.display = 'none';

    const applyConfigButtons = document.querySelectorAll('.apply-config');
    // const dryRunButton = document.getElementById('dry-run');

    const resolveAllButton = document.getElementById('resolve-all');

    let resolveConflicts = {};

    let isProcessing = false;

    function createOpenButtonHtml(abbrev) {
        return `<a id="open-action" class="action" href="../${abbrev}" target="_new">
            <svg class="icon"><use href="#icon-open-action"></use></svg>
        </a>`;
    }

    function getConfig(appConfig) {
        return fetch('api/expand', {
            method: 'post',
            body: JSON.stringify(appConfig),
            headers: {
                'Content-Type': 'application/json',
            }
        })
        .then((response) => {
            if (!response.ok) {
                return Promise.reject(response.status);
            }
    
            return response.json();
        });
    }

    async function loadApps(id) {
        try {
            const response = await fetch('api/configurations');
            if (!response.ok) {
                throw new Error(response.status);
            }
            const apps = await response.json();
            const nav = document.querySelector('.installed');
			nav.innerHTML = '';

            await loadColorPalettes(apps);

            apps.forEach(async (app) => {
                if (app.type === 'profile' && app.config.theme?.colors?.palettes) {
                    // Load color palettes from profile
                    Object.entries(app.config.theme.colors.palettes).forEach(([name, cssPath]) => {
                        colorPalettes[name] = `profiles/${app.profile}/resources/css/${cssPath}`;
                    });
                }

                if (app.type !== 'installed') {
                    return;
                }

                const li = document.createElement('li');
                li.innerHTML = `
                    <div>
                        <img src="resources/images/app.svg" width="64px">
                        <h3>${app.title}</h3>
                    </div>
                    <nav class="actions"></nav>
                `;
                const actions = li.querySelector('.actions');
                if (app.type === 'installed') {
                    actions.innerHTML = createOpenButtonHtml(app.config.pkg.abbrev);
                }
                if (app.description) {
                    li.dataset.tooltip = app.description;
                    li.dataset.placement = 'right';
                }
                nav.appendChild(li);

                const clickable = li.querySelector('div');
                clickable.addEventListener('click', (ev) => {
                    ev.preventDefault();
                    // Remove selected class from all installed items
                    document.querySelectorAll('.installed li').forEach(item => {
                        item.classList.remove('selected');
                    });
                    // Add selected class to clicked item
                    li.classList.add('selected');
                    loadApp(app);
                });
                if (id === app.config.id) {
                    li.classList.add('selected');
                    loadApp(app);
                }
            });
        } catch (error) {
            console.log(error);
        }
    }

    function loadApp(app) {
        resolveConflicts = {};
        appConfig = app.config;
        form.querySelector('[name="id"]').value = appConfig.id;
        form.querySelector('[name="label"]').value = appConfig.label;
        form.querySelector('[name="abbrev"]').value = appConfig.pkg.abbrev;
        form.querySelectorAll('[name="base"]').forEach((input) => {
            input.checked = appConfig.extends.includes(input.value);
        });
        form.querySelectorAll('[name="feature"],[name="blueprint"]').forEach((input) => {
            input.checked = appConfig.extends.includes(input.value);
        });

        updateColorPaletteSelection();

        const ul = document.getElementById('actions');
        ul.style.display = 'block';
        ul.innerHTML = '';
        if (app.actions) {
            const label = document.createElement('li');
            label.innerHTML = '<span>Actions:</span>';
            ul.appendChild(label);

            app.actions.forEach((action) => {
                const li = document.createElement('li');
                const btn = document.createElement('button');
                btn.dataset.action = action.name;
                btn.dataset.tooltip = action.name;
                btn.innerHTML = action.description;
                li.appendChild(btn);
                ul.appendChild(li);

                btn.addEventListener('click', (ev) => {
                    ev.preventDefault();
                    runAction(appConfig.pkg.abbrev, action.name);
                });
            });
        }
        editor.value = JSON.stringify(app.config, null, 2);
        update(false);
    }

    async function displaySpinnerDuringCallback(text, callback) {
        spinner.style.display = 'block';
        spinner.innerText = text;
        try {
            return await callback();
        } finally {
            spinner.style.display = 'none';
        }
    }

    async function blockUiDuringCallback(callback) {
        if (isProcessing) {
            throw new Error('Process already in progress');
        }
        // A double-click on deploying can cause a deadlock. Prevent double-clicks at least from the front-end.
        isProcessing = true;
        applyConfigButtons.forEach(button => button.disabled = true);
        // dryRunButton.disabled = true;
        try {
            return await callback()
        } finally {
            applyConfigButtons.forEach(button => button.disabled = false);
            // dryRunButton.disabled = false;
            isProcessing = false;
        }
    }

    async function doDeploy(abbrev, id) {
        return displaySpinnerDuringCallback(`Deploying app ${abbrev}…`, async () => {
            errors.innerHTML = '';

            try {
                const response = await fetch(
                    new URL(`api/generator/${abbrev}/deploy`, window.location),
                    {
                        method: 'POST',
                        body: {},
                        headers: {
                            'Content-Type': 'application/json',
                        }
                    },
                );

                if (!response.ok) {
                    const text = await response.text();
                    errors.innerHTML = text;

                    throw new Error(response.status);
                }

                output.innerHTML = `Package is deployed. Visit it here ${createOpenButtonHtml(abbrev)}`;
                loadApps(id);
            } catch (error) {
                console.log(error);
            }
        });
    }

    async function process(dryRun) {
        await blockUiDuringCallback(async () => {
            const result = await displaySpinnerDuringCallback(
                `Applying configuration…`,
                async () => {
                    try {
                        // Reset state
                        output.innerHTML = '';
                        errors.innerHTML = '';
                        resolveAllButton.style.display = 'none';
                        document.querySelector('#output-dialog').querySelector('.apply-config').style.display = 'none';

                        const overwrite = document.querySelector('[name=overwrite]').value;
                        const config = JSON.parse(editor.value);
                        const params = {
                            config: config,
                            resolve: []
                        };
                        Object.keys(resolveConflicts).forEach((key) => {
                            params.resolve.push(key);
                        });
                        resolveConflicts = {};

                        const url = new URL(`api/generator`, window.location);
                        url.searchParams.set('overwrite', overwrite);
                        if (dryRun) {
                            url.searchParams.set('dry', 'true');
                        }
                        const response = await fetch(url, {
                            method: 'POST',
                            body: JSON.stringify(params),
                            headers: {
                                'Content-Type': 'application/json',
                            },
                        });
                        if (!response.ok) {
                            const text = await response.text();
                            errors.innerHTML = text;

                            throw new Error(response.status);
                        }
                        const result = await response.json();

                        return result;
                    } catch (error) {
                        console.log(error);
                        // Fully stop processing.
                        throw error;
                    }
                },
            );

            if (result.messages) {
                output.innerHTML = '';
                if (
                    result.messages.length === 0 &&
                    !(result.nextStep.action === 'DEPLOY' || result.config._update === false)
                ) {
                    const li = document.createElement('li');
                    li.innerHTML = 'Update completed.';
                    output.appendChild(li);
                } else {
                    result.messages.forEach((message) => {
                        if (!message.type) {
                            return;
                        }
                        const li = document.createElement('li');
                        li.classList.add(message.type);
                        li.dataset.path = message.path;

                        li.innerHTML = `
                        <span class='badge ${message.type === 'conflict' ? 'alert' : ''}'
                            data-tooltip="${message.type === 'conflict' ?
                                'This file was modified since it was installed. No update was applied.' :
                                'The file was updated with the incoming version.'}"
                            data-placement="right">
                            ${message.type}
                        </span> 
                        ${message.path} ${message.source ? ' from ' + message.source.substring('/db/apps/jinks/'.length) : ''}`;
                        if (message.type === 'conflict' && message.incoming) {
                            document.querySelector('#output-dialog').querySelector('.apply-config').style.display = 'flex';

                            const copyButton = document.createElement('a');
                            copyButton.href = '#';
                            copyButton.dataset.tooltip = 'Copy incoming version to clipboard';
                            copyButton.innerHTML = `<svg class="icon"><use href="#icon-copy"></use></svg>`;
                            copyButton.addEventListener('click', (ev) => {
                                ev.preventDefault();
                                navigator.clipboard.writeText(message.incoming).then(() => {
                                    console.log('Copied to clipboard');
                                }).catch((err) => {
                                    console.error('Failed to copy: ', err);
                                });
                            });
                            li.appendChild(copyButton);

                            const cmpButton = document.createElement('a');
                            cmpButton.href = '#';
                            cmpButton.dataset.tooltip = 'Compare current version to incoming';
                            cmpButton.innerHTML = `<svg class="icon"><use href="#icon-compare"></use></svg>`;
                            li.appendChild(cmpButton);
                            cmpButton.addEventListener('click', (ev) => {
                                ev.preventDefault();
                                document.getElementById('output-dialog').setAttribute('wide', '');
                                let diff = li.querySelector('jinn-monaco-diff');
                                if (diff) {
                                    diff.close();
                                    return;
                                }
                                diff = document.createElement('jinn-monaco-diff');
                                diff.style.width = '100%';
                                li.appendChild(diff);
                                const url = new URL(`api/source?path=${encodeURIComponent(message.source)}`, window.location);
                                fetch(url)
                                .then((response) => {
                                    if (!response.ok) {
                                        throw new Error(response.status);
                                    }
                                    return response.text();
                                })
                                .then((text) => {
                                    console.log(text);
                                    diff.diff(text, message.incoming, message.mime);
                                });
                            });

                            const resolveBtn = document.createElement('a');
                            resolveBtn.href = '#';
                            resolveBtn.dataset.tooltip = 'Overwrite with next update';
                            resolveBtn.innerHTML = `<svg class="icon"><use href="#icon-resolve"></use></svg>`;
                            li.appendChild(resolveBtn);
                            resolveBtn.addEventListener('click', (ev) => {
                                ev.preventDefault();
                                
                                const badge = li.querySelector('.badge');
                                if (!li.classList.contains('overwrite')) {
                                    li.classList.add('overwrite');
                                    badge.className = 'badge resolved';
                                    badge.innerText = 'overwrite';
                                    resolveConflicts[message.path] = '';
                                } else {
                                    li.classList.remove('overwrite');
                                    badge.className = 'badge conflict';
                                    badge.innerText = 'conflict';
                                    delete resolveConflicts[message.path];
                                }
                            });
                            resolveAllButton.style.display = 'flex';
                        }
                        output.appendChild(li);
                    });
                }
            }

            if (
                result.nextStep.action === 'DEPLOY' ||
                result.config._update === false
            ) {
                await doDeploy(result.config.pkg.abbrev, result.config.id);
            } else {
                loadApps(result.config.id);
            }
            output.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'start' });
            
            // Show the output dialog after the update process completes
            const outputDialog = document.getElementById('output-dialog');
            if (outputDialog) {
                outputDialog.openDialog();
            }
        });
    }

    async function runAction(pkgAbbrev, actionName) {
        await blockUiDuringCallback(async () => {
            const result = await displaySpinnerDuringCallback(
                'Running action',
                async () => {
                    output.innerHTML = '';
                    errors.innerHTML = '';
                    const url = new URL(`../${pkgAbbrev}/api/actions/${actionName}`, window.location);
                    const response = await fetch(url, {
                        method: "POST",
                        body: {},
                        headers: {
                            'Content-Type': 'application/json',
                        }
                    });
                    if (!response.ok) {
                        const text = await response.text();
                        errors.innerHTML = text;

                        throw new Error(response.status);
                    }
                    const result = await response.json();
                    result.forEach((message) => {
                        const li = document.createElement('li');
                        li.innerHTML = `
                            <span class='badge'>${message.type}</span> 
                            ${message.message}
                        `;
                        output.append(li);
                    });
                }
            );
            
            // Show the output dialog after the action completes
            const outputDialog = document.getElementById('output-dialog');
            if (outputDialog) {
                outputDialog.openDialog();
            }
        });
    }
    
    function updateConfig(updateEditor = true) {
        getConfig(appConfig).then(async (config) => {
            mergedView.value = JSON.stringify(config, null, 2);

            document.querySelectorAll('.color-scheme-option').forEach((option) => {
                option.style.display = 'none';
            });
            Object.keys(config.theme?.colors?.palettes || {}).forEach((palette) => {
                const colorPaletteInput = form.querySelector(`.color-scheme-option[data-palette="${palette}"]`);
                if (colorPaletteInput) {
                    colorPaletteInput.style.display = 'block';
                }
            });

            updateColorPaletteSelection(config);
        });
        if (updateEditor && editor) {
            editor.value = JSON.stringify(appConfig, null, 2);
        }
    }

    function validateForm() {
        form.querySelectorAll(':invalid').forEach((element) => {
            element.setAttribute('aria-invalid', 'true');
        });
        form.querySelectorAll(':valid').forEach((element) => {
            element.setAttribute('aria-invalid', 'false');
        });
        const themes = form.querySelectorAll('input[name="theme"]');
        const valid = Array.from(themes).some(cb => cb.checked);
        if (!valid) {
            Array.from(themes).forEach((cb) => {
                cb.setAttribute('aria-invalid', 'true');
            });
        }
    }

    /**
     * Collects form data similar to FormData but includes elements with display: none
     * @param {HTMLFormElement} formElement - The form element to collect data from
     * @param {Object} options - Options for data collection
     * @param {boolean} options.includeHidden - Whether to include hidden elements (default: true)
     * @param {boolean} options.includeDisabled - Whether to include disabled elements (default: false)
     * @param {boolean} options.includeDisplayNone - Whether to include elements with display: none (default: true)
     * @returns {FormData} FormData object with all collected data
     */
    function collectFormData(formElement, options = {}) {
        const {
            includeHidden = true,
            includeDisabled = false,
            includeDisplayNone = true
        } = options;
        
        const formData = new FormData();
        
        // Get all form elements
        const elements = formElement.querySelectorAll('input, select, textarea, button');
        
        elements.forEach(element => {
            const name = element.name;
            const type = element.type;
            
            // Skip if no name
            if (!name) return;
            
            // Check if element should be included
            const isHidden = element.type === 'hidden';
            const isDisabled = element.disabled;
            const hasDisplayNone = window.getComputedStyle(element).display === 'none';
            
            // Skip based on options
            if (!includeHidden && isHidden) return;
            if (!includeDisabled && isDisabled) return;
            if (!includeDisplayNone && hasDisplayNone) return;
            
            // Handle different input types
            if (type === 'checkbox' || type === 'radio') {
                if (element.checked) {
                    formData.append(name, element.value);
                }
            } else if (type === 'file') {
                // Handle file inputs
                if (element.files && element.files.length > 0) {
                    for (let i = 0; i < element.files.length; i++) {
                        formData.append(name, element.files[i]);
                    }
                }
            } else if (type === 'select-multiple') {
                // Handle multi-select
                const selectedOptions = Array.from(element.selectedOptions);
                selectedOptions.forEach(option => {
                    formData.append(name, option.value);
                });
            } else {
                // Handle text, number, email, password, etc.
                formData.append(name, element.value);
            }
        });
        
        return formData;
    }

    function update(updateEditor = true) {
        // Get the form data including hidden elements
        let formData = collectFormData(form, {
            includeHidden: true,
            includeDisabled: false,
            includeDisplayNone: true
        });
        if (formData.get('abbrev') !== '') {
            if (formData.get('label') === '') {
                form.querySelector('[name="label"]').value = formData.get('abbrev');
            }
            if (formData.get('id') === '') {
                form.querySelector('[name="id"]').value = `https://e-editiones.org/apps/${formData.get('abbrev')}`;
            }
        }
        if (!formData.get('theme')) {
            form.querySelector('[name="theme"]').checked = true;
        }

        // Recreate the form data to get the latest values
        formData = new collectFormData(form, {
            includeHidden: true,
            includeDisabled: false,
            includeDisplayNone: true
        });
        
        formData.forEach((value, key) => {
            if (!['base', 'feature', 'theme', 'blueprint', 'abbrev', 'custom-odd', 'overwrite', 'color-palette'].includes(key)) {
                appConfig[key] = value;
            }
        });
        appConfig.pkg = {
            abbrev: formData.get('abbrev')
        };
        appConfig.extends = formData.getAll('base')
            .concat(formData.getAll('feature'))
            .concat(formData.getAll('theme'))
            .concat(formData.getAll('blueprint'));
        
        // Add color palette configuration
        const prevPalette = appConfig.theme?.colors?.palette;
        const colorPalette = formData.get('color-palette');
        if (
            (colorPalette && colorPalette !== 'neutral') || 
            (prevPalette && prevPalette !== 'neutral')) {
            if (!appConfig.theme) {
                appConfig.theme = {};
            }
            if (!appConfig.theme.colors) {
                appConfig.theme.colors = {};
            }
            appConfig.theme.colors.palette = colorPalette;
        }
        
        validateForm();
        updateConfig(updateEditor);
    }

    function toggleFeature(eventOrControl) {
        const target = eventOrControl.target || eventOrControl;
        const configExtends = JSON.parse(target.dataset.depends);
        if (configExtends) {
            configExtends.forEach((profile) => {
                const input = form.querySelector(`[value="${profile}"]`);
                if (!target.checked && input.name === 'base') {
                    return;
                }
                input.checked = target.checked;
                toggleFeature(input);
            });
        }
        update();
    }

    function reset(updateEditor = true) {
        appConfig = {};
        const ul = document.getElementById('actions');
        ul.style.display = 'none';
        ul.innerHTML = '';

        form.reset();
        form.querySelector('[name="theme"]').checked = true;
        update(updateEditor);

        const neutralPalette = form.querySelector(`input[name="color-palette"][value="neutral"]`);
        if (neutralPalette) {
            neutralPalette.checked = true;
            updateColorPickerSelection();
        }

        document.querySelector('.installed li.selected')?.classList.remove('selected');

        // Switch to config tab
        showTab('config');
    }

    // Function to handle apply config action
    function handleApplyConfig() {
        const outputDialog = document.getElementById('output-dialog');
        outputDialog.closeDialog();

        showTab('config');
        
        validateForm();
        if (!form.checkValidity()) {
            return;
        }
        const overwrite = document.querySelector('[name=overwrite]').value;
        if (overwrite === 'reinstall') {
            const messageDialog = document.getElementById('message-dialog');
            messageDialog.confirm('Warning', `This will completely reinstall the application. Local changes will be lost.`)
            .then(
                () => { process(false); },
                () => { return; }
            );
        } else {
            process(false);
        }
    }

    applyConfigButtons.forEach(button => {
        button.addEventListener('click', (ev) => {
            ev.preventDefault();
            handleApplyConfig();
        });
    });

    // Add keyboard shortcut for apply config (Cmd-Shift-s on Mac, Ctrl-Shift-s on Windows/Linux)
    if (typeof window.hotkeys !== 'undefined') {
        applyConfigButtons.forEach(button => {
            window.hotkeys(button.dataset.shortcut, (ev) => {
                ev.preventDefault();
                handleApplyConfig();
            });
        });
    }

    // dryRunButton.addEventListener('click', (ev) => {
    //     ev.preventDefault();
    //     validateForm();
    //     if (!form.checkValidity()) {
    //         return;
    //     }
    //     process(true);
    // });

    form.querySelectorAll('input[type="text"]:not(.action)').forEach((control) => control.addEventListener('change', update));
    form.querySelectorAll('input[type="checkbox"][name="feature"]').forEach((control) => control.addEventListener('change', toggleFeature));
    form.querySelectorAll('input[type="checkbox"][name="theme"]').forEach((control) => control.addEventListener('change', toggleFeature));
    form.querySelectorAll('input[type="checkbox"][name="blueprint"]').forEach((control) => control.addEventListener('change', toggleFeature));

    document.getElementById('reset').addEventListener('click', (ev) => {
        ev.preventDefault();
        reset();
    });

    document.getElementById('add-odd').addEventListener('click', (ev) => {
        ev.preventDefault();
        const odd = form.querySelector('[name="custom-odd"]');
        
        if (odd.checkValidity() && odd.value !== '') {
            if (!(appConfig.odds && Array.isArray(appConfig.odds))) {
                appConfig.odds = [];
            }
            appConfig.odds.push(odd.value);
            appConfig.defaults = appConfig.defaults || {};
            appConfig.defaults.odd = odd.value;
            
            updateConfig();
            odd.value = "";
        } else {
            odd.reportValidity();
        }
    });

    resolveAllButton.addEventListener('click', (ev) => {
        ev.preventDefault();
        const conflicts = output.querySelectorAll('.conflict');
        if (conflicts.length > 0) {
            Array.from(conflicts).forEach((li) => {
                resolveConflicts[li.dataset.path] = '';
                li.classList.add('overwrite');
                const badge = li.querySelector('.badge');
                badge.className = 'badge resolved';
                badge.innerText = 'overwrite';
            });
        }
    });

    editor.addEventListener('change', (e) => {
        appConfig = JSON.parse(e.target.value);
    });

    // Color scheme picker functionality
    let colorPickerInitialized = false;

    // Initialize color picker with event delegation
    function initializeColorPicker() {
        const paletteContainer = document.getElementById('color-scheme-picker');
        if (!paletteContainer || colorPickerInitialized) {
            return;
        }

        // Use event delegation for dynamically created elements
        paletteContainer.addEventListener('click', (e) => {
            const option = e.target.closest('.color-scheme-option');
            if (option && e.target.type !== 'radio') {
                const radio = option.querySelector('input[type="radio"]');
                if (radio) {
                    radio.checked = true;
                    updateColorPickerSelection();
                    update();
                }
            }
        });

        paletteContainer.addEventListener('change', (e) => {
            if (e.target.name === 'color-palette') {
                updateColorPickerSelection();
                update();
            }
        });

        const palette = appConfig.theme?.colors?.palette || 'neutral';
        paletteContainer.querySelector(`input[name="color-palette"][value="${palette}"]`).checked = true;

        updateColorPickerSelection();

        colorPickerInitialized = true;
    }

    // CSS Parser function to extract color values from palette CSS files
    async function parsePaletteCSS(cssUrl) {
        let cssText;
        try {
            // Use relative path directly, just like other API calls in this file
            const response = await fetch(cssUrl);
            if (!response.ok) {
                throw new Error(`Failed to fetch CSS: ${response.status} ${response.statusText}`);
            }
            cssText = await response.text();
        } catch (error) {
            // If fetch fails, try with absolute URL constructed from current location
            const pathname = window.location.pathname;
            const dirPath = pathname.substring(0, pathname.lastIndexOf('/') + 1);
            const absoluteUrl = window.location.origin + dirPath + cssUrl;
            const response = await fetch(absoluteUrl);
            if (!response.ok) {
                throw new Error(`Failed to fetch CSS: ${response.status} ${response.statusText}`);
            }
            cssText = await response.text();
        }
        
        // Extract color values using regex
        const colors = {};
        const colorRegex = /--jinks-colors-(700|500|200|50):\s*([^;]+);/g;
        let match;
        
        // Extract base color from comment for fallback
        const baseColorMatch = cssText.match(/Base color:\s*(#[0-9A-Fa-f]{6})/);
        const baseColor = baseColorMatch ? baseColorMatch[1] : null;
        
        while ((match = colorRegex.exec(cssText)) !== null) {
            const level = match[1];
            const value = match[2].trim();
            
            if (value.startsWith('#')) {
                // Direct hex value
                colors[level] = value;
            } else if (value.startsWith('hsl')) {
                // For HSL values, we need to compute them
                // Extract HSL values and compute the color
                const hslMatch = value.match(/hsl\(([^,]+),\s*([^,]+),\s*([^)]+)\)/);
                if (hslMatch) {
                    const h = hslMatch[1].trim();
                    const s = hslMatch[2].trim();
                    const l = hslMatch[3].trim();
                    
                    // If it's a CSS variable, we need to extract the actual value
                    if (h.includes('var(') || s.includes('var(') || l.includes('var(')) {
                        // Extract base HSL values from CSS
                        const baseHueMatch = cssText.match(/--base-hue:\s*([^;]+);/);
                        const baseSatMatch = cssText.match(/--base-saturation:\s*([^;]+);/);
                        const baseLightMatch = cssText.match(/--base-lightness:\s*([^;]+);/);
                        
                        if (baseHueMatch && baseSatMatch && baseLightMatch) {
                            const baseHue = baseHueMatch[1].trim();
                            const baseSat = baseSatMatch[1].trim();
                            const baseLight = baseLightMatch[1].trim();
                            
                            // Parse the lightness value (remove % if present)
                            const lightnessValue = l.replace('%', '');
                            
                            // Create computed HSL color
                            const computedHsl = `hsl(${baseHue}, ${baseSat}, ${lightnessValue}%)`;
                            colors[level] = computedHsl;
                        } else if (baseColor && level === '500') {
                            // Fallback to base color for 500 level
                            colors[level] = baseColor;
                        }
                    } else {
                        // Direct HSL value
                        colors[level] = value;
                    }
                }
            }
        }
        
        return colors;
    }

    // Create dynamic HTML for color scheme options
    function createColorSchemeOption(paletteName, colors) {
        const option = document.createElement('div');
        option.className = 'color-scheme-option';
        option.setAttribute('data-palette', paletteName);
        
        const preview = document.createElement('div');
        preview.className = 'color-preview';
        
        ['700', '500', '200', '50'].forEach(level => {
            if (colors[level]) {
                const swatch = document.createElement('div');
                swatch.className = 'color-swatch';
                swatch.style.background = colors[level];
                preview.appendChild(swatch);
            }
        });
        
        const label = document.createElement('label');
        const input = document.createElement('input');
        input.type = 'radio';
        input.name = 'color-palette';
        input.value = paletteName;
        
        const labelText = document.createTextNode(
            paletteName.charAt(0).toUpperCase() + paletteName.slice(1)
        );
        
        label.appendChild(input);
        label.appendChild(labelText);
        
        option.appendChild(preview);
        option.appendChild(label);
        
        return option;
    }

    // Load available color palettes from configurations
    async function loadColorPalettes(apps) {
        colorPalettes = {};
        apps.forEach(async (app) => {
            if (app.type === 'profile' && app.config.theme?.colors?.palettes && app.profile) {
                // Load color palettes from profile
                Object.entries(app.config.theme.colors.palettes).forEach(([name, cssPath]) => {
                    colorPalettes[name] = `profiles/${app.profile}/resources/css/${cssPath}`;
                });
            }
        });

        const paletteContainer = document.getElementById('color-scheme-picker');
        if (!paletteContainer) {
            return;
        }
        paletteContainer.innerHTML = ''; // Clear existing content
        for (const [name, cssPath] of Object.entries(colorPalettes)) {
            try {
                const colors = await parsePaletteCSS(cssPath);
                const option = createColorSchemeOption(name, colors);
                paletteContainer.appendChild(option);
            } catch (error) {
                console.error(`Failed to load palette ${name} from ${cssPath}:`, error);
            }
        }
        
        // Re-initialize color picker after dynamic loading
        initializeColorPicker();
    }

    function updateColorPickerSelection() {
        const colorSchemeOptions = document.querySelectorAll('.color-scheme-option');
        colorSchemeOptions.forEach(option => {
            const radio = option.querySelector('input[type="radio"]');
            if (radio && radio.checked) {
                option.setAttribute('data-selected', 'true');
                // Add visual feedback for selected option
                option.style.transform = 'scale(1.02)';
            } else {
                option.removeAttribute('data-selected');
                option.style.transform = 'scale(1)';
            }
        });
    }

    function updateColorPaletteSelection(config = appConfig) {
        // Load color palette selection
        const palette = config.theme?.colors?.palette || 'neutral';
        const colorPaletteInput = form.querySelector(`input[name="color-palette"][value="${palette}"]`);
        if (colorPaletteInput) {
            colorPaletteInput.checked = true;
            updateColorPickerSelection();
        }
    }

    // Tab functionality
    function initializeTabs() {
        const tabLinks = document.querySelectorAll('.tabs a[href^="#"]');
        const tabSections = document.querySelectorAll('[data-tab]');
        
        // Hide all tab sections initially
        tabSections.forEach(section => {
            section.style.display = 'none';
        });
        
        // Show the first tab by default
        if (tabSections.length > 0) {
            const firstTab = tabSections[0];
            const firstTabId = firstTab.getAttribute('data-tab');
            showTab(firstTabId);
        }
        
        // Add click handlers to tab links
        tabLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const targetTab = link.getAttribute('href').substring(1); // Remove the #
                showTab(targetTab);
            });
            if (typeof window.hotkeys !== 'undefined') {
                window.hotkeys(link.dataset.shortcut, (ev) => {
                    ev.preventDefault();
                    const targetTab = link.getAttribute('href').substring(1); // Remove the #
                    showTab(targetTab);
                });
            }
        });
    }
    
    function showTab(tabId) {
        // Hide all tab sections
        const tabSections = document.querySelectorAll('[data-tab]');
        tabSections.forEach(section => {
            section.style.display = 'none';
        });
        
        // Show the selected tab section
        const targetSection = document.querySelector(`[data-tab="${tabId}"]`);
        if (targetSection) {
            targetSection.style.display = 'block';
        }
        
        // Update active tab link
        const tabLinks = document.querySelectorAll('.tabs a[href^="#"]');
        tabLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === `#${tabId}`) {
                link.classList.add('active');
            }
        });
    }

    // Display configured keyboard shortcuts on mouseover
    document.querySelectorAll('[data-shortcut]').forEach((elem) => {
        const shortcut = elem.dataset.shortcut;
        const keys = shortcut.split(/\s*,\s*/);
        let output = keys[0];
        if (navigator.userAgent.indexOf('Mac OS X') === -1) {
            output = keys[1];
        }
        const title = elem.dataset.tooltip || '';
        elem.dataset.tooltip = `${title} [${output.replaceAll('+', ' ')}]`;
    });

    loadApps();
    reset(false);
    initializeTabs();
});