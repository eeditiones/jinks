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
            <p><strong>Collection Endpoint:</strong> <a href="${data.collection || '#'}" target="_blank">${data.collection || 'N/A'}</a></p>
            <p><strong>Documents Endpoint:</strong> <a href="${data.documents || '#'}" target="_blank">${data.documents || 'N/A'}</a></p>
            <p><strong>Navigation Endpoint:</strong> <a href="${data.navigation || '#'}" target="_blank">${data.navigation || 'N/A'}</a></p>

            <details>
                <summary>Raw JSON Response</summary>
                <pre><code>${JSON.stringify(data, null, 2)}</code></pre>
            </details>
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
                const memberCollectionUrl = member.collection || '';
                const memberDocumentUrl = member.document || '';
                const memberNavigationUrl = member.navigation || '';
                
                // Generate action button for documents only
                const actionButton = isCollection ? '' : 
                    `<button class="dts-action-btn view-document">View Document</button>`;
                
                tableBody += `
                    <tr>
                        <td><span class="member-type ${isCollection ? 'collection' : 'document'}">${memberType}</span></td>
                        <td><strong class="dts-title-clickable">${memberTitle}</strong></td>
                        <td><code>${memberId}</code></td>
                        <td>${memberDescription}</td>
                        <td>${actionButton}</td>
                    </tr>
                `;
            });
        } else {
            tableBody += '<tr><td colspan="5">No collection members found</td></tr>';
        }
        
        tableBody += '</tbody>';

        // Set table content
        collectionTable.innerHTML = tableHeader + tableBody;

        // Add click handlers for all titles (both collections and documents)
        addTitleClickHandlers(collectionData);
        
        // Add click handlers for document action buttons
        addDocumentActionHandlers(collectionData);
    }

    /**
     * Add click handlers for all titles (collections and documents)
     */
    function addTitleClickHandlers(collectionData) {
        const titleElements = collectionTable.querySelectorAll('.dts-title-clickable');
        titleElements.forEach((titleElement, index) => {
            // Get the member data from the current collection data
            const member = collectionData.member[index];
            if (!member) return;
            
            const memberType = member['@type'] || 'Unknown';
            const memberId = member['@id'] || member.id || '';
            const memberCollectionUrl = member.collection || '';
            const memberDocumentUrl = member.document || '';
            const memberNavigationUrl = member.navigation || '';
            const isCollection = memberType.toLowerCase().includes('collection');
            
            titleElement.addEventListener('click', function() {
                if (isCollection) {
                    // For collections, navigate to the collection
                    if (memberCollectionUrl) {
                        navigateToCollection(memberId, memberCollectionUrl);
                    } else {
                        console.error('DTS Client: No collection URL available for member:', memberId);
                    }
                } else {
                    // For documents, fetch metadata
                    if (memberNavigationUrl) {
                        fetchDocumentMetadata(memberId, memberNavigationUrl);
                    } else {
                        console.error('DTS Client: No navigation URL available for member:', memberId);
                    }
                }
            });
        });
    }

    /**
     * Fetch document metadata using the navigation endpoint
     */
    async function fetchDocumentMetadata(documentId, navigationUrlTemplate) {
        if (!navigationUrlTemplate) {
            console.error('DTS Client: No navigation URL template provided');
            return;
        }

        try {
            // Clear previous navigation response
            clearNavigationResponse();
            
            // Extract the resource ID from the document ID (format: collectionId/documentId)
            const resourceId = documentId;
            
            // Expand the navigation URL template with the resource parameter
            const expandedUrl = expandUriTemplate(navigationUrlTemplate, { resource: resourceId, down: 2 });
            console.log('DTS Client: Fetching metadata from navigation URL:', expandedUrl);
            
            // Make API call to navigation endpoint
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

            const navigationData = await response.json();
            
            // Display the navigation structure in aside
            displayDocumentStructure(navigationData);
            
            // Display the raw navigation response
            displayNavigationResponse(navigationData);

        } catch (error) {
            console.error('DTS Navigation Error:', error);
            displayDocumentMetadata({ title: `Error: ${error.message}` });
        }
    }

    /**
     * Display document structure in the aside element
     */
    function displayDocumentStructure(navigationData) {
        const asideElement = document.getElementById('dts-aside');
        if (!asideElement) {
            console.error('DTS Client: dts-aside element not found');
            return;
        }

        const resource = navigationData.resource || {};
        const members = navigationData.member || [];
        
        const title = resource.title || 'Unknown Title';
        const creator = resource.dublinCore?.creator || 'Unknown Author';
        const date = resource.dublinCore?.date || 'Unknown Date';
        const language = resource.dublinCore?.language || 'Unknown Language';

        // Filter for CitableUnits and organize by level
        const citableUnits = members.filter(member => 
            member['@type'] === 'CitableUnit'
        );

        let structureHtml = '';
        if (citableUnits.length > 0) {
            structureHtml = `
                <div class="document-structure">
                    <h4>Document Structure</h4>
                    ${buildHierarchicalStructure(citableUnits)}
                </div>
            `;
        } else {
            structureHtml = '<div class="document-structure"><p>No structure information available</p></div>';
        }

        asideElement.innerHTML = `
            <div class="dts-document-metadata">
                <h3>Document Information</h3>
                <div class="metadata-item">
                    <strong>Title:</strong> ${title}
                </div>
                <div class="metadata-item">
                    <strong>Creator:</strong> ${creator}
                </div>
                <div class="metadata-item">
                    <strong>Date:</strong> ${date}
                </div>
                <div class="metadata-item">
                    <strong>Language:</strong> ${language}
                </div>
                ${structureHtml}
            </div>
        `;
    }

    /**
     * Build hierarchical structure from CitableUnits
     */
    function buildHierarchicalStructure(citableUnits) {
        // Group CitableUnits by level
        const unitsByLevel = {};
        citableUnits.forEach(unit => {
            const level = unit.level || 1;
            if (!unitsByLevel[level]) {
                unitsByLevel[level] = [];
            }
            unitsByLevel[level].push(unit);
        });

        // Get the levels in order
        const levels = Object.keys(unitsByLevel).map(Number).sort((a, b) => a - b);
        
        if (levels.length === 0) {
            return '<p>No structure information available</p>';
        }

        // Build the structure starting from the first level
        return buildLevelStructure(unitsByLevel, levels, 0, citableUnits);
    }

    /**
     * Recursively build structure for a specific level
     */
    function buildLevelStructure(unitsByLevel, levels, levelIndex, allUnits) {
        if (levelIndex >= levels.length) {
            return '';
        }

        const currentLevel = levels[levelIndex];
        const currentUnits = unitsByLevel[currentLevel] || [];

        if (currentUnits.length === 0) {
            return buildLevelStructure(unitsByLevel, levels, levelIndex + 1, allUnits);
        }

        let html = '';
        
        currentUnits.forEach(unit => {
            const title = unit.dublinCore?.title || 'Untitled';
            const identifier = unit.identifier || '';
            
            // Find children of this unit (units with higher level and this unit as parent)
            const children = allUnits.filter(child => 
                child.level > currentLevel && 
                child.parent === identifier
            );

            if (children.length > 0) {
                // This unit has children, create an expandable details element
                const childrenHtml = buildLevelStructure(unitsByLevel, levels, levelIndex + 1, allUnits);
                html += `
                    <details class="structure-details level-${currentLevel}">
                        <summary class="structure-summary">
                            <span class="structure-title">${title}</span>
                        </summary>
                        <div class="structure-children">
                            ${childrenHtml}
                        </div>
                    </details>
                `;
            } else {
                // This unit has no children, create a simple div
                html += `
                    <div class="structure-item level-${currentLevel}">
                        <span class="structure-title">${title}</span>
                    </div>
                `;
            }
        });

        return html;
    }

    /**
     * Clear navigation response display
     */
    function clearNavigationResponse() {
        const navigationJsonElement = document.getElementById('dts-navigation-json');
        const navigationResponseElement = document.getElementById('dts-navigation-response');
        
        if (navigationJsonElement && navigationResponseElement) {
            navigationJsonElement.textContent = '';
            navigationResponseElement.querySelector('summary').textContent = 'Navigation Response';
            navigationResponseElement.open = false;
        }
    }

    /**
     * Display raw navigation response in details element
     */
    function displayNavigationResponse(navigationData) {
        const navigationJsonElement = document.getElementById('dts-navigation-json');
        const navigationResponseElement = document.getElementById('dts-navigation-response');
        
        if (!navigationJsonElement || !navigationResponseElement) {
            console.error('DTS Client: Navigation response elements not found');
            return;
        }

        // Display the raw JSON response
        navigationJsonElement.textContent = JSON.stringify(navigationData, null, 2);
        navigationResponseElement.querySelector('summary').textContent = 'Navigation Response';
        navigationResponseElement.open = false; // Keep it collapsed by default
    }

    /**
     * Display document metadata in the aside element (fallback)
     */
    function displayDocumentMetadata(metadata) {
        const asideElement = document.getElementById('dts-aside');
        if (!asideElement) {
            console.error('DTS Client: dts-aside element not found');
            return;
        }

        const title = metadata.title || 'Unknown Title';
        const creator = metadata.dublinCore?.creator || 'Unknown Author';
        const date = metadata.dublinCore?.date || 'Unknown Date';
        const language = metadata.dublinCore?.language || 'Unknown Language';

        asideElement.innerHTML = `
            <div class="dts-document-metadata">
                <h3>Document Metadata</h3>
                <div class="metadata-item">
                    <strong>Title:</strong> ${title}
                </div>
                <div class="metadata-item">
                    <strong>Creator:</strong> ${creator}
                </div>
                <div class="metadata-item">
                    <strong>Date:</strong> ${date}
                </div>
                <div class="metadata-item">
                    <strong>Language:</strong> ${language}
                </div>
            </div>
        `;
    }

    /**
     * Add click handlers for document action buttons
     */
    function addDocumentActionHandlers(collectionData) {
        const actionButtons = collectionTable.querySelectorAll('.dts-action-btn.view-document');
        actionButtons.forEach((button, index) => {
            // Get the member data from the current collection data
            const member = collectionData.member[index];
            if (!member) return;
            
            const memberId = member['@id'] || member.id || '';
            const memberDocumentUrl = member.document || '';
            
            button.addEventListener('click', function() {
                // For documents, open in new tab using the document URL
                if (memberDocumentUrl) {
                    viewDocument(memberId, memberDocumentUrl);
                } else {
                    console.error('DTS Client: No document URL available for member:', memberId);
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
