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

function search(index, fields, query, facetPlace) {
    const results = document.getElementById('results');
    const placesDiv = document.getElementById('places');
    results.innerHTML = '';
    placesDiv.innerHTML = '';

    const queryOptions = {
        suggest: false,
        enrich: true,
        limit: 100
    };
    if (fields !== 'all') {
        if (!Array.isArray(fields)) {
            fields = [fields];
        }
        queryOptions.field = fields;
    }
    places = [];
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
            if (!facetPlace || facetPlace.length === 0) {
                return true;
            }
            if (!entry.doc.places) {
                return false;
            }
            return entry.doc.places.some((place) => facetPlace.indexOf(place) > -1);
        });
        const info = document.createElement('h4');
        if (result.length === 100) {
            info.innerHTML = `Showing first 100 matches.`;
        } else {
            info.innerHTML = `Found ${result.length} matches.`;
        }
        results.appendChild(info);

        const tokens = [query, ...query.split(/\W+/)];
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

            if (data.doc.places) {
                data.doc.places.forEach(place => places.push(place));
            }

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
        outputPlaces(places, facetPlace || []);
    });
}

function outputPlaces(places, facetPlace) {
    places = [...new Set(places)].sort();
    const div = document.getElementById('places');
    places.forEach(place => {
        const label = document.createElement('label');
        const input = document.createElement('input');
        input.type = 'checkbox';
        input.name = 'place';
        input.value = place;
        input.checked = facetPlace.indexOf(place) > -1;
        input.addEventListener('change', function(ev) {
            pbEvents.emit('pb-search-resubmit', 'search');
        });
        label.appendChild(input);
        const text = document.createTextNode(place);
        label.appendChild(text);
        div.appendChild(label);
    });
}

document.addEventListener('DOMContentLoaded', function() {
    let loading = false;
    let places = [];
    const page = document.querySelector('pb-page');
    page.addEventListener('pb-page-ready', function(ev) {
        if (loading) {
            return;
        }
        loading = true;
        const index = new FlexSearch.Document({
            tokenize: "strict",
            context: true,
            document: {
                id: "id",
                index: ["content", "translation", "commentary"],
                store: ["content", "translation", "commentary", "title", "link", "tag", "places"]
            }
        });

        const params = new URLSearchParams(location.search);
        const query = params.get('query');
        if (query) {
            document.getElementById('search-input').value = query;
        }
        const fields = params.getAll('field');
        if (fields.length > 0) {
            fields.forEach(field => {
                const input = document.querySelector(`input[name="field"][value="${field}"]`);
                if (input) {
                    input.checked = true;
                }
            });
        }

        pbEvents.subscribe('pb-load', null, (ev) => {
            const query = ev.detail.params.query;
            search(index, ev.detail.params.field, query, ev.detail.params.place);
        });

        pbEvents.emit('pb-start-update', 'transcription');
        fetch(`${page.endpoint}/index.json`)
        .then((response) => {
            if (!response.ok) {
                throw new Error('Network response was not OK');
            }
            return response.json();
        })
        .then((text) => {
            text.forEach((doc, idx) => {
                try {
                    const indexParams = {
                        id: idx,
                        ...doc
                    };
                    index.add(indexParams);
                    if (doc.places) {
                        doc.places.forEach(place => places.push(place));
                    }
                } catch (e) {
                    console.log('error parsing "%s"', doc);
                }
            });

            if (query) {
                search(index, params.get('field'), params.get('query'), params.getAll('place'));
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