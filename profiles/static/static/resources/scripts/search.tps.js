[% if map:contains($static, 'facets') %]
const facetNames = [[ serialize($static?facets, map { "method": "json" })]];
[% else %]
const facetNames = [];
[% endif %]
const indexedFields = [[ serialize($static?fields?index, map { "method": "json" })]];
const storedFields = [[ serialize($static?fields?store, map { "method": "json" })]];

function kwicText(str, start, end, words = 5) {
    let p0 = start - 1;
    let count = 0;
    while (p0 >= 0) {
        if (/[\p{P}\s]/.test(str.charAt(p0))) {
            while (p0 > 1 && /[\p{P}\s]/.test(str.charAt(p0 - 1))) {
                p0 -= 1;
            }
            count += 1;
            if (count === words) {
                break;
            }
        }
        p0 -= 1;
    }
    let p1 = end + 1;
    count = 0;
    while (p1 < str.length) {
        if (/[\p{P}\s]/.test(str.charAt(p1))) {
            while (p1 < str.length - 1 && /[\p{P}\s]/.test(str.charAt(p1 + 1))) {
                p1 += 1;
            }
            count += 1;
            if (count === words) {
                break;
            }
        }
        p1 += 1;
    }
    return `... ${str.substring(p0, start)}<mark>${str.substring(start, end)}</mark>${str.substring(end, p1 + 1)} ...`;
}

/**
 * 
 * @param {*} index 
 * @param {string[]} fields 
 * @param {string} query 
 * @param {[{facet: string, value: string[]}]} facets 
 */
function search(index, fields, query, facets) {
    const results = document.getElementById('results');
    // clear facet outputs
    facetNames.forEach((facet) => {
        const output = document.querySelector(`.facet.${facet} div`);
        if (output) {
            output.innerHTML = '';
        }
    });

    results.innerHTML = '';

    const queryOptions = {
        suggest: false,
        enrich: true,
        limit: 100,
        charset: 'utf-8'
    };
    if (fields && fields.length > 0 && fields !== 'all') {
        if (!Array.isArray(fields)) {
            fields = [fields];
        }
        queryOptions.field = fields;
    }
    let facetValues = {};
    index.searchAsync(query, 100, queryOptions).then((resultsByField) => {
        let result = [];
        resultsByField.forEach(byField => {
            byField.result.forEach((match) => { 
                result.push({
                    field: byField.field,
                    doc: match.doc
                })
            });
        });

        result = result.filter((entry) => {
            return facets.every(({dimension, value}) => {
                if (!entry.doc[dimension]) {
                    return false;
                }
                return entry.doc[dimension].some((facet) => value.includes(facet.id));
            });
        });
        
        const info = document.createElement('h4');
        if (result.length === 100) {
            info.innerHTML = `Showing first 100 matches.`;
        } else {
            info.innerHTML = `Found ${result.length} matches.`;
        }
        results.appendChild(info);

        const tokens = [query, ...query.split(/[\p{P}\s]+/u)];
        const regex = new RegExp(tokens.join('|'), 'gi');
        for (const data of result) {
            const div = document.createElement('div');
            const header = document.createElement('header');
            header.className = "title";
            div.appendChild(header);
            const head = document.createElement('h3');
            head.className = 'mb-0';
            head.innerHTML = `<a href="${data.doc.link}">${data.doc.title}</a>`;
            header.appendChild(head);

            facetNames.forEach((dimension) => {
                if (data.doc[dimension]) {
                    if (facetValues[dimension]) {
                        facetValues[dimension].push(...data.doc[dimension]);
                    } else {
                        facetValues[dimension] = data.doc[dimension];
                    }
                }
            });

            if (data.doc.tag) {
                const tags = document.createElement('ul');
                tags.className = 'tags';
                if (Array.isArray(data.doc.tag)) {
                    data.doc.tag.forEach((tag) => {
                        const li = document.createElement('li');
                        li.innerHTML = `<span class="badge">${tag}</span>`;
                        tags.appendChild(li);
                    });
                } else {
                    const li = document.createElement('li');
                    li.innerHTML = `<span class="badge">${data.doc.tag}</span>`;
                    tags.appendChild(li);
                }
                header.appendChild(tags);
            }

            const list = document.createElement('ul');
            let matches = Array.from(data.doc[data.field].matchAll(regex));
            if (matches.length > 10) {
                matches = matches.slice(0, 3);
            }
            for (const match of matches) {
                const kwic = kwicText(data.doc[data.field], match.index, match.index + match[0].length, 5);
                const li = document.createElement('li');
                li.innerHTML = kwic;
                list.appendChild(li);
            }
            div.appendChild(list);

            results.appendChild(div);
        }

        const queryFacets = {};
        facets.forEach(({dimension, value}) => {
            queryFacets[dimension] = value;
        });
        Object.entries(facetValues).forEach(([dimension, values]) => {
            outputFacet(dimension, values, queryFacets);
        });
    });
}

function outputFacet(dimension, values, queryFacets) {
    const uniqueValues = Array.from(new Set(values.map(value => value.id)))
        .map(id => values.find(value => value.id === id));
    const sortedValues = uniqueValues.sort((a, b) => a.place.localeCompare(b.place));
    const div = document.querySelector(`.facet.${dimension} div`);
    const searchForm = document.getElementById('search-form');
    sortedValues.forEach(value => {
        const label = document.createElement('label');
        const input = document.createElement('input');
        input.type = 'checkbox';
        input.name = dimension;
        input.value = value.id;
        if (queryFacets[dimension]) {
            input.checked = queryFacets[dimension].indexOf(value.id) > -1;
        }
        input.addEventListener('change', function(ev) {
            searchForm.dispatchEvent(new Event('submit', { 'bubbles': true, 'cancelable': true }));
        });
        label.appendChild(input);
        const text = document.createTextNode(value.place);
        label.appendChild(text);
        div.appendChild(label);
    });
}

document.addEventListener('DOMContentLoaded', function() {
    let loading = false;
    const page = document.querySelector('pb-page');
    page.addEventListener('pb-page-ready', function(ev) {
        if (loading) {
            return;
        }
        loading = true;
        const index = new FlexSearch.Document({
            tokenize: "forward",
            encode: false,
            document: {
                id: "id",
                index: indexedFields,
                store: storedFields
            }
        });

        const params = new URLSearchParams(location.search);
        const query = params.get('query');
        if (query) {
            document.getElementById('search-input').value = query;
        }
        const fields = params.getAll('field');
        if (fields.length > 0) {
            document.querySelectorAll('input[name="field"]').forEach(input => { input.checked = false; })
            fields.forEach(field => {
                const input = document.querySelector(`input[name="field"][value="${field}"]`);
                if (input) {
                    input.checked = true;
                }
            });
        }

        const searchForm = document.getElementById('search-form');
        searchForm.addEventListener('submit', function(ev) {
            ev.preventDefault();
            const formData = new FormData(searchForm);
            const params = new URLSearchParams();
            for (const [key, value] of formData.entries()) {
                params.append(key, value);
            }
            history.replaceState(null, '', `${location.pathname}?${params.toString()}`);

            const query = formData.get('query');
            const fields = formData.getAll('field');
            const facets = [];
            facetNames.forEach((facet) => {
                if (formData.has(facet)) {
                    facets.push({
                        dimension: facet,
                        value: formData.getAll(facet) || []
                    });
                }
            });
            
            search(index, fields, query, facets);
        });

        pbEvents.emit('pb-start-update', 'transcription');
        fetch(`${page.endpoint}/index.jsonl`)
        .then((response) => {
            if (!response.ok) {
                throw new Error('Network response was not OK');
            }
            return response.text();
        })
        .then((text) => {
            const lines = text.split('\n');
            lines.forEach((line, idx) => {
                const doc = JSON.parse(line);
                try {
                    const indexParams = {
                        id: idx,
                        ...doc
                    };
                    index.add(indexParams);
                } catch (e) {
                    console.log('error parsing "%s"', doc);
                }
            });

            if (query) {
                const facets = [];
                facetNames.forEach((facet) => {
                    if (params.has(facet)) {
                        facets.push({
                            dimension: facet,
                            value: params.getAll(facet) || []
                        });
                    }
                });
                search(index, params.getAll('field'), params.get('query'), facets);
            }
            pbEvents.emit('pb-end-update', 'transcription');
        })
        .catch(error => {
            console.log(error);
            document.getElementById('results').innerHTML = 'Request failed!';
            pbEvents.emit('pb-end-update', 'transcription');
        });
    });
});