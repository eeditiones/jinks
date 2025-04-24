/**
 * Send editor content to the API endpoint
 * @param {string} doc - The document identifier
 * @param {string} content - The editor content to send
 * @returns {Promise} A promise that resolves when the request is complete
 */
async function sendToApi(baseUri, doc, title, content) {
    const saveBtn = document.getElementById("saveBtn");
    
    try {
        // Update button state
        saveBtn.disabled = true;
        
        const response = await fetch(`${baseUri}/api/jinntap/${doc}?title=${encodeURIComponent(title)}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/xml'
            },
            body: `<body xmlns="http://www.tei-c.org/ns/1.0">${content}</body>`
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