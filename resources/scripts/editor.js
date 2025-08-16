window.addEventListener('DOMContentLoaded', () => {
    let appConfig = {};

    let editor = document.getElementById('appConfig');
    const mergedView = document.getElementById('mergedConfig');
    const form = document.getElementById('config');
    const output = document.querySelector('.output');
    const errors = document.querySelector('.error');

    const spinner = document.getElementById('spinner');
    spinner.style.display = 'none';

    const applyConfigButton = document.getElementById('apply-config');
    const dryRunButton = document.getElementById('dry-run');

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
            apps.forEach((app) => {
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
                    loadApp(app);
                });
                if (id === app.config.id) {
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

        document.getElementById('actions').innerHTML = '';
        if (app.actions) {
            app.actions.forEach((action) => {
                const btn = document.createElement('button');
                btn.dataset.action = action.name;
                btn.dataset.tooltip = action.description;
                btn.innerHTML = action.name;
                document.getElementById('actions').appendChild(btn);

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
        applyConfigButton.disabled = true;
        dryRunButton.disabled = true;
        try {
            return await callback()
        } finally {
            applyConfigButton.disabled = false;
            dryRunButton.disabled = false;
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
                result.messages.forEach((message) => {
                    if (!message.type) {
                        return;
                    }
                    const li = document.createElement('li');
                    li.classList.add(message.type);
                    li.dataset.path = message.path;
                    li.innerHTML = `
                    <span class='badge ${message.type === 'conflict' ? 'alert' : ''}'>${message.type}</span> 
                    ${message.path} ${message.source ? ' from ' + message.source : ''}`;
                    if (message.type === 'conflict' && message.incoming) {
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
                            let diff = li.querySelector('jinn-monaco-diff');
                            if (diff) {
                                diff.close();
                                return;
                            }
                            diff = document.createElement('jinn-monaco-diff');
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
                        resolveAllButton.style.display = 'block';
                    }
                    output.appendChild(li);
                });
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
        });
    }
    function updateConfig(updateEditor = true) {
        getConfig(appConfig).then((mergedConfig) => {
            mergedView.value = JSON.stringify(mergedConfig, null, 2);
        });
        if (updateEditor) {
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

    function update(updateEditor = true) {
        const formData = new FormData(form);
        if (formData.get('abbrev') !== '') {
            if (formData.get('label') === '') {
                form.querySelector('[name="label"]').value = formData.get('abbrev');
            }
            if (formData.get('id') === '') {
                form.querySelector('[name="id"]').value = `https://e-editiones.org/apps/${formData.get('abbrev')}`;
            }
        }
        new FormData(form).forEach((value, key) => {
            if (key !== 'base' && key !== 'feature' && key !== 'theme' && key !== 'blueprint' && key !== 'abbrev' && key !== 'custom-odd') {
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
            });
        }
        update();
    }

    applyConfigButton.addEventListener('click', (ev) => {
        ev.preventDefault();
        validateForm();
        if (!form.checkValidity()) {
            return;
        }
        process(false);
    });

    dryRunButton.addEventListener('click', (ev) => {
        ev.preventDefault();
        validateForm();
        if (!form.checkValidity()) {
            return;
        }
        process(true);
    });

    form.querySelectorAll('input[type="text"]:not(.action)').forEach((control) => control.addEventListener('change', update));
    form.querySelectorAll('input[type="checkbox"][name="feature"]').forEach((control) => control.addEventListener('change', toggleFeature));
    form.querySelectorAll('input[type="checkbox"][name="theme"]').forEach((control) => control.addEventListener('change', toggleFeature));
    form.querySelectorAll('input[type="checkbox"][name="blueprint"]').forEach((control) => control.addEventListener('change', toggleFeature));

    document.getElementById('reset').addEventListener('click', (ev) => {
        appConfig = {};
        document.getElementById('actions').innerHTML = '';
        updateConfig(true);
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

    loadApps();
});