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
        .then((response) => response.json())
        .then((apps) => {
            apps.forEach((app) => {
                const a = document.createElement('a');
                a.innerHTML = `
                    <div>
                        <img src="pages/${app.type}.svg" width="64px">
                        <h3>${app.title}</h3>
                    </div>
                `;
                nav.appendChild(a);

                a.addEventListener('click', () => {
                    editor.value = JSON.stringify(app.config, null, 4);
                });
            });
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
                    const li = document.createElement('li');
                    li.innerHTML = `<span class="badge ${message.type === 'conflict' ? 'alert' : ''}">${message.type}</span> ${message.path}`;
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
});