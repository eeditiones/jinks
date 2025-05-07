/**
 * Send editor content to the API endpoint
 * @param {string} doc - The document identifier
 * @param {string} content - The editor content to send
 * @returns {Promise} A promise that resolves when the request is complete
 */
async function save(baseUri, editor) {
    const doc = editor.metadata.name;

    try {
        const response = await fetch(`${baseUri}/api/document/${doc}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/xml'
            },
            body: editor.xml
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const json = await response.json();
        if (json.status === "ok") {
            document.dispatchEvent(new CustomEvent('jinn-toast', {
                detail: {
                    message: `File saved as ${doc}`,
                    type: 'info'
                }
            }));
        } else {
            document.dispatchEvent(new CustomEvent('jinn-toast', {
                detail: {
                    message: 'Saving the document failed!',
                    type: 'error'
                }
            }));
        }
    } catch (error) {
        document.dispatchEvent(new CustomEvent('jinn-toast', {
            detail: {
                message: error.message || 'Error saving document',
                type: 'error'
            }
        }));
        console.error('Error sending content to API:', error);
        throw error;
    }
}

async function copyToClipboard(editor) {
    const xml = editor.xml;
    await navigator.clipboard.writeText(xml);
    
    // Show success message
    document.dispatchEvent(new CustomEvent('jinn-toast', {
        detail: {
            message: 'XML content copied to clipboard',
            type: 'info'
        }
    }));
}

function initEditor(contextPath, doc) {
    const saveBtn = document.getElementById("saveBtn");
    const saveDialog = document.getElementById("saveDialog");
    const saveForm = document.querySelector('#saveDialog form');
    const copyBtn = document.getElementById("copyBtn");
    const editor = document.querySelector('jinn-tap');

    saveBtn.addEventListener("click", function () {
        if (doc) {
            save(contextPath, editor);
        } else {
            saveDialog.showModal();
        }
    });

    saveForm.addEventListener("submit", function (event) {
        event.preventDefault();
        const formData = new FormData(this);
        const docName = formData.get('docName').trim();
        const docTitle = formData.get('docTitle').trim();

        if (docName) {
            editor.metadata.name = doc = docName;
            editor.metadata.title = docTitle;
            saveDialog.close();
            this.reset();
            save(contextPath, editor);
        }
    });

    copyBtn.addEventListener("click", function () {
        copyToClipboard(editor);
    });

    // Set initial metadata if doc is provided
    if (doc) {
        editor.metadata.name = doc;
    }
}