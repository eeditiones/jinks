/**
 * Send editor content to the API endpoint
 * @param {string} doc - The document identifier
 * @param {string} content - The editor content to send
 * @returns {Promise} A promise that resolves when the request is complete
 */
async function sendToApi(baseUri, doc, content) {
    const saveBtn = document.getElementById("saveBtn");
    const originalTooltip = saveBtn.dataset.tooltip;
    
    try {
        // Update button state
        saveBtn.disabled = true;
        saveBtn.dataset.tooltip = "Saving...";
        
        const response = await fetch(`${baseUri}/api/jinntap/${doc}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/xml'
            },
            body: `<body xmlns="http://www.tei-c.org/ns/1.0">${content}</body>`
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        return await response.json();
    } catch (error) {
        console.error('Error sending content to API:', error);
        throw error;
    } finally {
        // Restore button state
        saveBtn.disabled = false;
        saveBtn.dataset.tooltip = originalTooltip;
    }
}