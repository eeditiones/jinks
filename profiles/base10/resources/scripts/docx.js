
function insertBeforeAfter(node, content, type = 'before') {
    const style = window.getComputedStyle(node, `::${type}`);
    if (style.content !== 'none') {
        content.push(new docx.TextRun({
            text: style.content
        }));
    }
}

function getStyle(node) {
    const list = Array.from(node.classList);
    const cls = list.filter((className) => !(className.startsWith('tei-') || className.startsWith('simple_')));
    return cls[0];
}

function process(node, content, footnotes) {
    if (!node) {
        return content;
    }

    if (node.nodeType === Node.ELEMENT_NODE) {
        const nodeName = node.nodeName.toLowerCase();
        let elem;
        let children = [];
        if (/^h[1-6]$/.test(nodeName)) {
            process(node.firstChild, children, footnotes);
            let level = parseInt(nodeName.substr(1));
            if (level > 6) {
                level = 6;
            }
            elem = new docx.Paragraph({
                children,
                heading: `Heading${level}`
            });
        } else {
            switch (nodeName) {
                case 'w-document':
                case 'div':
                    process(node.firstChild, content, footnotes);
                    break;
                case 'p':
                    process(node.firstChild, children, footnotes);
                    elem = new docx.Paragraph({
                        children
                    });
                    break;
                case 'span':
                    insertBeforeAfter(node, content);
                    if (node.textContent.length > 0) {
                        elem = new docx.TextRun({
                            text: node.textContent,
                            style: getStyle(node)
                        });
                    }
                    insertBeforeAfter(node, content, 'after');
                    break;
                case 'w-note':
                    const noteIndex = footnotes.indexOf(node);
                    elem = new docx.FootnoteReferenceRun(noteIndex + 1);
                    break;
            }
        }
        if (elem) {
            content.push(elem);
        }
    } else if (node.nodeType === Node.TEXT_NODE && node.nodeValue.trim() !== '') {
        let text = node.nodeValue;
        if (node.parentNode.nodeName.toLowerCase() === 'p') {
            text = node.nodeValue.trim();
        }
        const stripped = text.replace(/[\s\n]{2,}/g, ' ');
        content.push(new docx.TextRun({ text: stripped }));
    }
    process(node.nextSibling, content, footnotes);
}

function loadCSS(odd) {
    new Promise((resolve, reject) => {
        fetch(`${odd.endpoint}/transform/${encodeURIComponent(odd)}.css`, {
            mode: "cors",
            credentials: "same-origin"
        })
        .then((response) => {
            if (response.ok) {
                return response.text();
            }
            reject();
        })
        .then((text) => {
            const style = document.createElement('style');
            style.textContent = text;
            document.head.appendChild(style);

            const sheet = style.sheet;
            // Iterate over the CSSRuleList
            const rules = sheet.cssRules;
            for (let i = 0; i < rules.length; i++) {
                const rule = rules[i];
                if (rule instanceof CSSStyleRule) {
                    console.log(`${rule.selectorText} { ${rule.style.cssText} }`);
                }
            }
            resolve();
        });
    });
}

document.addEventListener('pb-page-ready', (ev) => {
    const endpoint = ev.detail.endpoint;
    const doc = document.querySelector('pb-document');
    const contentDiv = document.querySelector('#content');
    const odd = doc.odd;

    fetch(`${endpoint}/api/document/${encodeURIComponent(doc.path)}/wp`, {
        mode: "cors",
        credentials: "same-origin"
    })
    .then((response) => {
        if (response.ok) {
            return response.text();
        }
    })
    .then(async (text) => {
        await loadCSS(odd);
        contentDiv.innerHTML = text;

        const notes = Array.from(contentDiv.querySelectorAll('w-note'));

        const docxContent = [];
        process(contentDiv, docxContent, notes);

        const footnotes = {};
        notes.forEach((note, index) => {
            const noteContent = [];
            process(note.firstChild, noteContent, []);
            const para = new docx.Paragraph({
                children: noteContent
            });
            footnotes[index + 1] = { children: [para] };
        });

        const doc = new docx.Document({
            styles: {
                characterStyles: [
                    {
                        id: "persName",
                        name: "Underline",
                        basedOn: "Normal",
                        quickFormat: true,
                        run: {
                            underline: {
                                type: docx.UnderlineType.SINGLE,
                            },
                        }
                    }
                ]
            },
            footnotes,
            sections: [
                {
                    properties: {},
                    children: docxContent
                }
            ]
        });

        docx.Packer.toBlob(doc).then((blob) => {
            saveAs(blob, "example.docx");
            console.log("Document created successfully");
        });
    });
});