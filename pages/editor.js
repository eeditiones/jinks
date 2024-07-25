window.addEventListener('DOMContentLoaded', () => {
    const nav = document.querySelector('.profiles');
    const editor = document.querySelector('jinn-codemirror');
    const output = document.querySelector('.output');
    const errors = document.querySelector('.error');
    const spinner = document.getElementById('spinner');
    spinner.style.display = 'none';

    function loadConfigs() {
        nav.innerHTML = '';
        fetch("api/configurations")
        .then((response) => {
            if (response.ok) {
                return response.json();
            }
            throw new Error(response.status);
        })
        .then((apps) => {
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
                    actions.innerHTML = `
                        <a id="open-action" class="action" href="../${app.config.pkg.abbrev}" target="_new">
                            <svg xmlns="http://www.w3.org/2000/svg" class="ionicon" viewBox="0 0 512 512"><path d="M384 224v184a40 40 0 01-40 40H104a40 40 0 01-40-40V168a40 40 0 0140-40h167.48M336 64h112v112M224 288L440 72" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="32"/></svg>
                        </a>
                    `;
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
        })
        .catch((error) => {
            console.log(error);
        });
    }

    function process(dryRun) {
        output.innerHTML = '';
        errors.innerHTML = '';
        const overwrite = document.querySelector('[name=overwrite]').value;
        const config = JSON.parse(editor.value);
        const profile = config.profiles[config.profiles.length - 1];
        const url = new URL(`api/generator/${profile}`, window.location);
        url.searchParams.set('overwrite', overwrite);
        if (dryRun) {
            url.searchParams.set('dry', 'true');
        }
        spinner.style.display = 'block';
        fetch(url, {
            method: 'POST',
            body: JSON.stringify(config),
            headers: {
                'Content-Type': 'application/json'
            }
        })
        .then((response) => {
            if (response.ok) {
                return response.json();
            }
            response.text().then((text) => {
                errors.innerHTML = text;
            });
            throw new Error(response.status);
        })
        .then((result) => {
            spinner.style.display = 'none';
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
            loadConfigs();
        })
        .catch((error) => {
            console.log(error);
            spinner.style.display = 'none';
        });
    }

    document.getElementById('apply-config').addEventListener('click', () => process(false));
    document.getElementById('dry-run').addEventListener('click', () => process(true));
    loadConfigs();

    pbEvents.subscribe('pb-login', null, function(ev) {
        if (ev.detail.userChanged) {
            loadConfigs();
        }
    });
});