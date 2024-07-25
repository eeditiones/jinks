let examples = {};

function toggleOutput(show) {
    document.querySelectorAll('.output').forEach((output) => {
        if (show) {
            output.classList.remove('hidden');
        } else {
            output.classList.add('hidden');
        }
    });
}

function loadExamples(select) {
    fetch('pages/demo/sample-templates.json')
    .then((response) => response.json())
    .then((data) => {
        data.forEach((example, idx) => {
            const option = document.createElement('option');
            option.innerText = example.description;
            select.appendChild(option);

            examples[example.description] = example;
        });
    });
}

window.addEventListener('DOMContentLoaded', () => {
    const editor = document.getElementById('template');
    const parameters = document.getElementById('parameters');
    const output = document.getElementById('output');
    const error = document.getElementById('errorMsg');
    const xqueryCode = document.getElementById('xquery');
    const ast = document.getElementById('ast');
    const html = document.getElementById('html');
    const select = document.getElementById('examples');
    const modes = document.querySelector('[name=modes]');

    loadExamples(select);
    select.addEventListener('change', () => {
        toggleOutput(false);
        if (select.value === '') {
            editor.value = '';
            return;
        }
        const example = examples[select.value];
        editor.mode = example.mode;
        editor.value = example.template;
        parameters.value = JSON.stringify(example.params, null, 4);
    });

    document.getElementById('eval').addEventListener('click', () => {
        toggleOutput(true);
        output.code = '';
        html.innerHTML = '';
        xqueryCode.code = '';
        ast.code = '';
        error.innerHTML = '';
        const code = editor.value;
        const params = JSON.parse(parameters.value);
        const body = {
            template: code,
            params: params,
            mode: modes.value
        };
        try {
            fetch('api/templates', {
                method: 'POST',
                mode: "cors",
                credentials: "same-origin",
                body: JSON.stringify(body),
                headers: {
                    "Content-Type": "application/json",
                }
            })
            .then((response) => {
                if (!response.ok) {
                    response.json().then((data) => { 
                        error.innerText = data.description || data;
                        xqueryCode.code = data.code;
                        ast.code = data.ast;
                    });
                } else {
                    return response.json();
                }
            })
            .then((data) => {
                output.language = modes.value;
                output.code = data.result;
                html.innerHTML = data.result;
                xqueryCode.code = data.xquery;
                ast = data.ast;
            });
        } catch (error) {
            error.innerText = error.description;
        }
    });
});