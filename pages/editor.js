window.addEventListener('DOMContentLoaded', () => {
    const nav = document.querySelector('.profiles');
    const editor = document.querySelector('jinn-codemirror');
    const output = document.querySelector('.output');
    const errors = document.querySelector('.error');

    const spinner = document.getElementById('spinner');
    spinner.style.display = 'none';

    const deployNewPackage = document.getElementById('deploy-new-package');
    deployNewPackage.style.display = 'none';

    function createOpenButtonHtml(abbrev) {
        return `<a id="open-action" class="action" href="../${abbrev}" target="_new">
        <svg xmlns="http://www.w3.org/2000/svg" class="ionicon" viewBox="0 0 512 512"><path d="M384 224v184a40 40 0 01-40 40H104a40 40 0 01-40-40V168a40 40 0 0140-40h167.48M336 64h112v112M224 288L440 72" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="32"/></svg>
        </a>`;
    }

    async function loadConfigs() {
        nav.innerHTML = '';
        try {
            const response = await fetch("api/configurations")
            if (!response.ok) {
                throw new Error(response.status);
            }
            const apps = await response.json();
            apps.forEach((app) => {
                const a = document.createElement('a');
                a.innerHTML = `
                    <div>
                        <nav class="actions"></nav>
                        <img class="${app.type}" src="pages/app.svg" width="64px">
                        <h3>${app.title}</h3>
                    </div>
                `;
                const actions = a.querySelector('.actions');
                if (app.type === 'installed') {
                    actions.innerHTML = createOpenButtonHtml(app.config.pkg.abbrev);
                }
                if (app.description) {
                    a.dataset.tooltip = app.description;
                    a.dataset.placement = "right";
                }
                nav.appendChild(a);

                a.addEventListener('click', () => {
                    editor.value = JSON.stringify(app.config, null, 4);
                });
            });
        }
        catch (error) {
            console.log(error);
        }
    }

    async function displaySpinnerDuringCallback(text, callback) {
        spinner.style.display = 'block';
        spinner.innerText = text;
        await callback();
        spinner.style.display = 'none';
    }

    function displayDeployButton(abbrev) {
        deployNewPackage.style.display = 'block';
        const doDeploy = async () =>
            displaySpinnerDuringCallback(
                `Deploying app ${abbrev}…`,
                async () => {
                    try {

                        output.innerHTML = '';
                        errors.innerHTML = '';
                        const response = await fetch(new URL(`api/generator/${abbrev}/deploy`, window.location), {
                            method: 'POST',
                            body: {},
                            headers: {
                                'Content-Type': 'application/json'
                            }
                        });

                        if (!response.ok) {
                            const text = await response.text()
                            errors.innerHTML = text;

                            throw new Error(response.status);
                        }

                     
                        output.innerHTML = `Package is deployed. Visit it here ${createOpenButtonHtml(abbrev)}`;

                        deployNewPackage.removeEventListener('click', doDeploy);
                        deployNewPackage.style.display = 'none';
                    }
                    catch (error) {
                        console.log(error);
                    }
                    finally {
                        loadConfigs();
                    }
                });

        deployNewPackage.addEventListener('click', doDeploy)
    }

    async function process(dryRun) {
        displaySpinnerDuringCallback(
            `Applying configuration…`,
            async () => {
                try {
                    // Reset state
                    output.innerHTML = '';
                    errors.innerHTML = '';
                    deployNewPackage.style.display = 'none';

                    const overwrite = document.querySelector('[name=overwrite]').value;
                    const config = JSON.parse(editor.value);
                    const profile = config.profiles[config.profiles.length - 1];
                    const url = new URL(`api/generator/${profile}`, window.location);
                    url.searchParams.set('overwrite', overwrite);
                    if (dryRun) {
                        url.searchParams.set('dry', 'true');
                    }
                    spinner.style.display = 'block';
                    const response = await fetch(url, {
                        method: 'POST',
                        body: JSON.stringify(config),
                        headers: {
                            'Content-Type': 'application/json'
                        }
                    });
                    if (!response.ok) {
                        const text = await response.text()
                        errors.innerHTML = text;

                        throw new Error(response.status);
                    }
                    const result = await response.json();

                    if (result.messages) {
                        output.innerHTML = '';
                        result.messages.forEach((message) => {
                            if (!message.type) {
                                return;
                            }
                            const li = document.createElement('li');
                            li.innerHTML = `
                        <span class="badge ${message.type === 'conflict' ? 'alert' : ''}">${message.type}</span> 
                        ${message.path} ${message.source ? ' from ' + message.source : ''}
                    `;
                            output.appendChild(li);
                        });
                    }

                    if (result.nextStep.action === 'DEPLOY') {
                        displayDeployButton(result.config.pkg.abbrev);
                        const li = document.createElement('li');
                        output.prepend(li);
                        li.innerHTML = `<span class="badge alert">Deploy required</span> The package ${result.config.pkg.abbrev} is not deployed yet because it is new.`;

                    }
                    loadConfigs();
                }
                catch (error) {
                    console.log(error);
                }
            });
    }
    document.getElementById('apply-config').addEventListener('click', () => process(false));
    document.getElementById('dry-run').addEventListener('click', () => process(true));
    loadConfigs();

    pbEvents.subscribe('pb-login', null, function (ev) {
        if (ev.detail.userChanged) {
            loadConfigs();
        }
    });
});