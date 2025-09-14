/**
 * Send editor content to the API endpoint
 * @param {string} doc - The document identifier
 * @param {string} content - The editor content to send
 * @returns {Promise} A promise that resolves when the request is complete
 */
async function save(baseUri, editor) {
    const doc = editor.metadata.name;

    try {
        const response = await fetch(`${baseUri}/api/document/${encodeURIComponent(doc)}`, {
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
                    message: `File saved as ${json.path}`,
                    type: 'info'
                }
            }));
            // Change the URL if the document is now in some other place (happens for newly created documents)
            // Keep into account collections though: 'a/b.xml' will be saved in 'a/b.xml', not in some other location.
            // TODO: consider URIEncoding the collection and path to prevent this.
            if (!window.location.pathname.endsWith(json.path)) {
                const url = new URL(json.path, window.location.href);
                url.searchParams.set('template', 'editor.html');
                history.pushState({}, '', url.toString());
            }
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
    const editor = document.querySelector('jinn-tap');

    editor.addEventListener('ready', () => {
        const saveBtn = editor.querySelector(".saveBtn");
        const copyBtn = editor.querySelector(".copyBtn");
        const saveDialog = document.getElementById("saveDialog");
        const saveForm = document.querySelector('#saveDialog form');

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

        // Listen for cancel button to abort saving
        const cancelBtn = saveDialog.querySelector('.cancel');
        if (cancelBtn) {
            cancelBtn.addEventListener("click", function () {
                saveDialog.close();
                saveForm.reset();
                // Optionally show a message that saving was cancelled
                document.dispatchEvent(new CustomEvent('jinn-toast', {
                    detail: {
                        message: 'Save cancelled',
                        type: 'info'
                    }
                }));
            });
        }

        copyBtn.addEventListener("click", function () {
            copyToClipboard(editor);
        });

        // Set initial metadata if doc is provided
        if (doc) {
            editor.metadata.name = doc;
        }
    });
}
