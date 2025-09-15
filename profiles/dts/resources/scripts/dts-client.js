/**
 * DTS Client - Distributed Text Services API Client
 * Handles connection to DTS Entry Endpoint and displays server information
 */

// Initialize DTS client when DOM is ready
function initializeDTSClient() {
    // Get DOM elements with error checking
    const connectButton = document.getElementById('dts-connect');
    const serverUrlInput = document.getElementById('dts-server-url');
    const serverInfoDiv = document.getElementById('dts-server-info');
    const collectionTable = document.getElementById('dts-collection');
    const rawResponseDetails = document.getElementById('dts-raw-response');
    const rawJsonCode = document.getElementById('dts-raw-json');
    const paginationNav = document.getElementById('dts-pagination');
    const paginationFirst = document.getElementById('dts-pagination-first');
    const paginationPrevious = document.getElementById('dts-pagination-previous');
    const paginationInfo = document.getElementById('dts-pagination-info');
    const paginationNext = document.getElementById('dts-pagination-next');
    const paginationLast = document.getElementById('dts-pagination-last');
    const breadcrumbsNav = document.getElementById('dts-breadcrumbs');
    const breadcrumbsList = breadcrumbsNav ? breadcrumbsNav.querySelector('ul') : null;

    // Check for missing core elements
    if (!connectButton || !serverUrlInput || !serverInfoDiv || !collectionTable || !rawResponseDetails || !rawJsonCode) {
        console.error('DTS Client: Core elements not found in DOM');
        return;
    }

    // Check for pagination elements
    if (!paginationNav || !paginationFirst || !paginationPrevious || !paginationInfo || !paginationNext || !paginationLast) {
        console.error('DTS Client: Pagination elements not found in DOM');
        return;
    }

    // Check for breadcrumbs elements
    if (!breadcrumbsNav || !breadcrumbsList) {
        console.error('DTS Client: Breadcrumbs elements not found in DOM');
        return;
    }

    // Store server configuration for API calls
    let serverConfig = null;
    
    // Collection navigation state
    let currentCollectionId = null;
    let collectionHistory = [];
    let collectionUriTemplate = null;
    
    // Pagination state
    let currentPagination = null;
    let currentPage = 1;

    // Add click handler for connect button
    connectButton.addEventListener('click', function() {
        connectToDTS();
    });

    // Also allow Enter key in the URL input
    serverUrlInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            connectToDTS();
        }
    });

    // Add pagination event handlers
    paginationFirst.addEventListener('click', () => navigateToPage(1));
    paginationPrevious.addEventListener('click', () => navigateToPage(currentPage - 1));
    paginationNext.addEventListener('click', () => navigateToPage(currentPage + 1));
    paginationLast.addEventListener('click', () => navigateToPage(getLastPageNumber()));

    /**
     * Connect to DTS Entry Endpoint and display server information
     */
    async function connectToDTS() {
        const serverUrl = serverUrlInput.value.trim();
        
        if (!serverUrl) {
            displayError('Please enter a server URL');
            return;
        }

        // Show loading state
        setLoadingState(true);
        clearServerInfo();
        clearRawResponse();

        try {
            // Make API call to Entry Endpoint
            const response = await fetch(serverUrl, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();
            serverConfig = data; // Store server configuration
            displayServerInfo(data);
            displayRawResponse(data, 'Entry Endpoint');
            
            // Fetch and display root collection
            await fetchRootCollection();

        } catch (error) {
            console.error('DTS Client Error:', error);
            displayError(`Failed to connect to DTS server: ${error.message}`);
        } finally {
            setLoadingState(false);
        }
    }

    /**
     * Display server information in the info div
     */
    function displayServerInfo(data) {
        serverInfoDiv.innerHTML = `
            <div class="dts-server-response">
                <h3>DTS Server Information</h3>
                <div class="dts-server-details">
                    <p><strong>Context:</strong> ${data['@context'] || 'N/A'}</p>
                    <p><strong>ID:</strong> ${data['@id'] || 'N/A'}</p>
                    <p><strong>Type:</strong> ${data['@type'] || 'N/A'}</p>
                    <p><strong>Collection Endpoint:</strong> <a href="${data.collection || '#'}" target="_blank">${data.collection || 'N/A'}</a></p>
                    <p><strong>Documents Endpoint:</strong> <a href="${data.documents || '#'}" target="_blank">${data.documents || 'N/A'}</a></p>
                    <p><strong>Navigation Endpoint:</strong> <a href="${data.navigation || '#'}" target="_blank">${data.navigation || 'N/A'}</a></p>
                </div>
                <details>
                    <summary>Raw JSON Response</summary>
                    <pre><code>${JSON.stringify(data, null, 2)}</code></pre>
                </details>
            </div>
        `;
    }

    /**
     * Display error message
     */
    function displayError(message) {
        serverInfoDiv.innerHTML = `
            <div class="dts-error">
                <h3>Connection Error</h3>
                <p>${message}</p>
            </div>
        `;
    }

    /**
     * Clear server info display
     */
    function clearServerInfo() {
        serverInfoDiv.innerHTML = '';
    }

    /**
     * Fetch root collection from DTS API
     */
    async function fetchRootCollection() {
        if (!serverConfig || !serverConfig.collection) {
            console.error('DTS Client: No server configuration or collection URL available');
            return;
        }

        try {
            // Clear previous collection data and reset state
            clearCollectionTable();
            currentCollectionId = null;
            collectionHistory = [];
            collectionUriTemplate = serverConfig.collection;
            currentPagination = null;
            currentPage = 1;
            hidePagination();

            // Expand the collection template for the root collection
            const rootCollectionUrl = expandUriTemplate(serverConfig.collection, {});
            console.log('DTS Client: Root collection URL:', rootCollectionUrl);
            
            // Make API call to collection endpoint
            const response = await fetch(rootCollectionUrl, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const collectionData = await response.json();
            displayCollectionTable(collectionData, 'Root Collection');
            displayRawResponse(collectionData, 'Root Collection');
            handlePagination(collectionData);
            

        } catch (error) {
            console.error('DTS Collection Error:', error);
            displayCollectionError(`Failed to fetch collection: ${error.message}`);
        }
    }

    /**
     * Display collection data in the table
     */
    function displayCollectionTable(collectionData, collectionTitle = 'Collection') {
        // Update breadcrumb navigation
        updateBreadcrumbs(collectionTitle);
        
        // Create table header
        const tableHeader = `
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Title</th>
                    <th>ID</th>
                    <th>Description</th>
                    <th>Actions</th>
                </tr>
            </thead>
        `;

        // Create table body with collection members
        let tableBody = '<tbody>';
        
        if (collectionData.member && Array.isArray(collectionData.member)) {
            collectionData.member.forEach(member => {
                const memberType = member['@type'] || 'Unknown';
                const memberTitle = member.title || member.label || 'Untitled';
                const memberId = member['@id'] || member.id || '';
                const memberDescription = member.description || '';
                
                // Determine if this is a collection or document
                const isCollection = memberType.toLowerCase().includes('collection');
                const actionText = isCollection ? 'Browse Collection' : 'View Document';
                const actionClass = isCollection ? 'browse-collection' : 'view-document';
                const memberCollectionUrl = member.collection || '';
                const memberDocumentUrl = member.document || '';
                
                // Only add URL data attributes if they exist
                const collectionUrlAttr = memberCollectionUrl ? `data-member-collection-url="${memberCollectionUrl}"` : '';
                const documentUrlAttr = memberDocumentUrl ? `data-member-document-url="${memberDocumentUrl}"` : '';
                
                tableBody += `
                    <tr>
                        <td><span class="member-type ${isCollection ? 'collection' : 'document'}">${memberType}</span></td>
                        <td><strong>${memberTitle}</strong></td>
                        <td><code>${memberId}</code></td>
                        <td>${memberDescription}</td>
                        <td>
                            <button class="dts-action-btn ${actionClass}" data-member-id="${memberId}" data-member-type="${memberType}" ${collectionUrlAttr} ${documentUrlAttr}>
                                ${actionText}
                            </button>
                        </td>
                    </tr>
                `;
            });
        } else {
            tableBody += '<tr><td colspan="5">No collection members found</td></tr>';
        }
        
        tableBody += '</tbody>';

        // Set table content
        collectionTable.innerHTML = tableHeader + tableBody;

        // Add click handlers for action buttons
        addCollectionActionHandlers();
    }

    /**
     * Add click handlers for collection action buttons
     */
    function addCollectionActionHandlers() {
        const actionButtons = collectionTable.querySelectorAll('.dts-action-btn');
        actionButtons.forEach(button => {
            button.addEventListener('click', function() {
                const memberId = this.getAttribute('data-member-id');
                const memberType = this.getAttribute('data-member-type');
                const memberCollectionUrl = this.getAttribute('data-member-collection-url');
                const memberDocumentUrl = this.getAttribute('data-member-document-url');
                const isCollection = memberType.toLowerCase().includes('collection');
                
                if (isCollection) {
                    if (memberCollectionUrl) {
                        // Navigate to the subcollection using the collection URL from the member entry
                        navigateToCollection(memberId, memberCollectionUrl);
                    } else {
                        console.error('DTS Client: No collection URL available for member:', memberId);
                    }
                } else {
                    // For documents, open in new tab using the document URL
                    if (memberDocumentUrl) {
                        viewDocument(memberId, memberDocumentUrl);
                    } else {
                        console.error('DTS Client: No document URL available for member:', memberId);
                    }
                }
            });
        });
    }

    /**
     * View a document in a new tab
     */
    function viewDocument(documentId, documentUrl) {
        if (!documentUrl) {
            console.error('DTS Client: No document URL provided');
            return;
        }

        try {
            // Expand the URI template to get the actual document URL
            const expandedUrl = expandUriTemplate(documentUrl, { resource: documentId });
            console.log('DTS Client: Opening document URL:', expandedUrl);
            
            // Open the document in a new tab
            window.open(expandedUrl, '_blank');
        } catch (error) {
            console.error('DTS Client: Error opening document:', error);
        }
    }

    /**
     * Navigate to a specific collection
     */
    async function navigateToCollection(collectionId, collectionUrl = null) {
        if (!collectionUrl) {
            console.error('DTS Client: No collection URL provided');
            return;
        }

        try {
            // Add current collection to history if we're not at root
            if (currentCollectionId !== null) {
                collectionHistory.push(currentCollectionId);
            }

            // Update current collection ID
            currentCollectionId = collectionId;

            // Expand the URI template to get the actual URL
            // The collectionUrl already contains the correct id parameter, just expand any remaining template syntax
            const expandedUrl = expandUriTemplate(collectionUrl, {});
            console.log('DTS Client: Expanded collection URL:', expandedUrl);

            // Make API call to collection endpoint
            const response = await fetch(expandedUrl, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const collectionData = await response.json();
            const collectionTitle = collectionData.title || collectionData.label || `Collection: ${collectionId}`;
            displayCollectionTable(collectionData, collectionTitle);
            displayRawResponse(collectionData, `Collection: ${collectionId}`);
            handlePagination(collectionData);

        } catch (error) {
            console.error('DTS Collection Navigation Error:', error);
            displayCollectionError(`Failed to navigate to collection: ${error.message}`);
        }
    }

    /**
     * Expand URI template according to RFC 6570
     */
    function expandUriTemplate(template, variables = {}) {
        let url = template;
        
        // Handle simple variable substitution {id}
        Object.keys(variables).forEach(key => {
            const value = encodeURIComponent(variables[key]);
            url = url.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
        });
        
        // Handle query parameter expansion {&param1,param2}
        url = url.replace(/\{&([^}]+)\}/g, (match, params) => {
            const paramList = params.split(',').map(p => p.trim());
            const queryParams = [];
            
            paramList.forEach(param => {
                if (variables[param] !== undefined) {
                    queryParams.push(`${param}=${encodeURIComponent(variables[param])}`);
                }
            });
            
            return queryParams.length > 0 ? '&' + queryParams.join('&') : '';
        });
        
        // Handle other template expressions by removing them if no variables provided
        url = url.replace(/\{[^}]+\}/g, '');
        
        return url;
    }


    /**
     * Update breadcrumb navigation using existing nav element
     */
    function updateBreadcrumbs(currentTitle) {
        // Clear existing breadcrumbs
        breadcrumbsList.innerHTML = '';
        
        // Add root link
        const rootLi = document.createElement('li');
        const rootLink = document.createElement('a');
        rootLink.className = 'dts-breadcrumb-item';
        rootLink.setAttribute('data-action', 'navigate');
        rootLink.setAttribute('data-target', 'root');
        rootLink.href = '#';
        rootLink.textContent = '🏠 Root';
        rootLi.appendChild(rootLink);
        breadcrumbsList.appendChild(rootLi);
        
        // Add history items
        collectionHistory.forEach((collectionId, index) => {
            const historyLi = document.createElement('li');
            const historyButton = document.createElement('button');
            historyButton.className = 'dts-breadcrumb-item';
            historyButton.setAttribute('data-action', 'navigate');
            historyButton.setAttribute('data-target', 'history');
            historyButton.setAttribute('data-index', index);
            historyButton.textContent = `Collection ${index + 1}`;
            historyLi.appendChild(historyButton);
            breadcrumbsList.appendChild(historyLi);
        });
        
        // Add current collection
        if (currentCollectionId) {
            const currentLi = document.createElement('li');
            const currentSpan = document.createElement('span');
            currentSpan.className = 'dts-breadcrumb-current';
            currentSpan.textContent = currentTitle;
            currentLi.appendChild(currentSpan);
            breadcrumbsList.appendChild(currentLi);
        }
        
        // Add click handlers for breadcrumb navigation
        addBreadcrumbHandlers();
    }

    /**
     * Navigate back to root collection
     */
    async function navigateToRoot() {
        currentCollectionId = null;
        collectionHistory = [];
        await fetchRootCollection();
    }

    /**
     * Navigate back to a previous collection in history
     */
    async function navigateToHistory(index) {
        // Remove items after the target index from history
        collectionHistory = collectionHistory.slice(0, index);
        
        // If index is 0, go to root
        if (index === 0) {
            await navigateToRoot();
        } else {
            // Navigate to the collection at the specified index
            const targetCollectionId = collectionHistory[index - 1];
            await navigateToCollection(targetCollectionId);
        }
    }

    /**
     * Add click handlers for breadcrumb navigation
     */
    function addBreadcrumbHandlers() {
        const breadcrumbItems = breadcrumbsList.querySelectorAll('.dts-breadcrumb-item');
        breadcrumbItems.forEach(item => {
            // Remove existing event listeners to prevent duplicates
            item.replaceWith(item.cloneNode(true));
        });
        
        // Add fresh event listeners
        const freshBreadcrumbItems = breadcrumbsList.querySelectorAll('.dts-breadcrumb-item');
        freshBreadcrumbItems.forEach(item => {
            item.addEventListener('click', function(event) {
                // Prevent default link behavior
                event.preventDefault();
                
                const action = this.getAttribute('data-action');
                const target = this.getAttribute('data-target');
                
                if (action === 'navigate') {
                    if (target === 'root') {
                        navigateToRoot();
                    } else if (target === 'history') {
                        const index = parseInt(this.getAttribute('data-index'));
                        navigateToHistory(index);
                    }
                }
            });
        });
    }

    /**
     * Display collection error
     */
    function displayCollectionError(message) {
        collectionTable.innerHTML = `
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Title</th>
                    <th>ID</th>
                    <th>Description</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td colspan="5" class="error-message">
                        <strong>Error:</strong> ${message}
                    </td>
                </tr>
            </tbody>
        `;
    }

    /**
     * Clear collection table
     */
    function clearCollectionTable() {
        collectionTable.innerHTML = '';
    }

    /**
     * Display raw JSON response
     */
    function displayRawResponse(data, requestType = 'API Response') {
        rawJsonCode.textContent = JSON.stringify(data, null, 2);
        rawResponseDetails.querySelector('summary').textContent = `Raw JSON Response (${requestType})`;
        rawResponseDetails.open = false; // Keep it collapsed by default
    }

    /**
     * Clear raw response display
     */
    function clearRawResponse() {
        rawJsonCode.textContent = '';
        rawResponseDetails.querySelector('summary').textContent = 'Raw JSON Response';
        rawResponseDetails.open = false;
    }

    /**
     * Handle pagination from collection response
     */
    function handlePagination(collectionData) {
        if (collectionData.view && collectionData.view['@type'] === 'Pagination') {
            currentPagination = collectionData.view;
            showPagination();
            updatePaginationControls();
        } else {
            hidePagination();
        }
        
        // Store the collection template for pagination
        if (collectionData.collection) {
            collectionUriTemplate = collectionData.collection;
        }
    }

    /**
     * Show pagination controls
     */
    function showPagination() {
        paginationNav.style.display = 'block';
    }

    /**
     * Hide pagination controls
     */
    function hidePagination() {
        paginationNav.style.display = 'none';
    }

    /**
     * Update pagination control states
     */
    function updatePaginationControls() {
        if (!currentPagination) {
            hidePagination();
            return;
        }

        // Extract page numbers from URLs
        const currentPageNum = extractPageFromUrl(currentPagination['@id']) || 1;
        const firstPageNum = extractPageFromUrl(currentPagination.first) || 1;
        const lastPageNum = extractPageFromUrl(currentPagination.last) || 1;
        const previousPageNum = currentPagination.previous ? extractPageFromUrl(currentPagination.previous) : null;
        const nextPageNum = currentPagination.next ? extractPageFromUrl(currentPagination.next) : null;

        // Update current page
        currentPage = currentPageNum;

        // Update button states
        paginationFirst.disabled = currentPageNum <= firstPageNum;
        paginationPrevious.disabled = !previousPageNum || currentPageNum <= firstPageNum;
        paginationNext.disabled = !nextPageNum || currentPageNum >= lastPageNum;
        paginationLast.disabled = currentPageNum >= lastPageNum;

        // Update page info
        paginationInfo.textContent = `Page ${currentPageNum} of ${lastPageNum}`;
    }

    /**
     * Extract page number from URL
     */
    function extractPageFromUrl(url) {
        if (!url) return null;
        const match = url.match(/[?&]page=(\d+)/);
        return match ? parseInt(match[1]) : null;
    }

    /**
     * Get last page number from pagination
     */
    function getLastPageNumber() {
        if (!currentPagination || !currentPagination.last) return 1;
        return extractPageFromUrl(currentPagination.last) || 1;
    }

    /**
     * Navigate to a specific page
     */
    async function navigateToPage(pageNumber) {
        if (!currentPagination || !collectionUriTemplate) {
            console.error('DTS Client: No pagination or collection template available');
            return;
        }

        // Validate page number
        if (pageNumber < 1) {
            console.warn('DTS Client: Page number must be >= 1, got:', pageNumber);
            return;
        }

        // Check if page number exceeds last page
        const lastPage = getLastPageNumber();
        if (pageNumber > lastPage) {
            console.warn('DTS Client: Page number exceeds last page, got:', pageNumber, 'max:', lastPage);
            return;
        }

        console.log('DTS Client: Navigating to page', pageNumber);

        try {
            // Construct URL for the specific page
            const pageUrl = constructPageUrl(pageNumber);

            // Make API call to collection endpoint with page parameter
            const response = await fetch(pageUrl, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const collectionData = await response.json();
            const collectionTitle = collectionData.title || collectionData.label || 
                (currentCollectionId ? `Collection: ${currentCollectionId}` : 'Root Collection');
            
            displayCollectionTable(collectionData, collectionTitle);
            displayRawResponse(collectionData, `Page ${pageNumber}`);
            handlePagination(collectionData);

        } catch (error) {
            console.error('DTS Pagination Error:', error);
            displayCollectionError(`Failed to navigate to page ${pageNumber}: ${error.message}`);
        }
    }

    /**
     * Construct URL for a specific page
     */
    function constructPageUrl(pageNumber) {
        if (!collectionUriTemplate) {
            console.error('DTS Client: No collection template available for pagination');
            return null;
        }
        
        // Prepare variables for URI template expansion
        const variables = { page: pageNumber };
        
        if (currentCollectionId) {
            variables.id = currentCollectionId;
        }
        
        // Use URI template expansion with the page number and collection ID
        const url = expandUriTemplate(collectionUriTemplate, variables);
        console.log('DTS Client: Constructed URL for page', pageNumber, ':', url);
        return url;
    }

    /**
     * Set loading state for the connect button
     */
    function setLoadingState(loading) {
        if (loading) {
            connectButton.disabled = true;
            connectButton.textContent = 'Connecting...';
        } else {
            connectButton.disabled = false;
            connectButton.textContent = 'Connect';
        }
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initializeDTSClient);
