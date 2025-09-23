/**
 * DTS Client - Distributed Text Services API Client
 * Handles connection to DTS Entry Endpoint and displays server information
 */

// Initialize DTS client when DOM is ready
function initializeDTSClient() {
    // Get DOM elements with error checking
    const connectButton = document.getElementById('dts-connect');
    const serverListSelect = document.getElementById('dts-server-list');
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
    if (!connectButton || !serverListSelect || !serverInfoDiv || !collectionTable || !rawResponseDetails || !rawJsonCode) {
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

    // Add pagination event handlers
    paginationFirst.addEventListener('click', () => navigateToPage(1));
    paginationPrevious.addEventListener('click', () => navigateToPage(currentPage - 1));
    paginationNext.addEventListener('click', () => navigateToPage(currentPage + 1));
    paginationLast.addEventListener('click', () => navigateToPage(getLastPageNumber()));

    // Load available DTS servers on initialization
    loadDTSServers();

    /**
     * Load available DTS servers from the API
     */
    async function loadDTSServers() {
        try {
            const response = await fetch('../jinks/api/dts/list', {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const servers = await response.json();
            populateServerList(servers);
        } catch (error) {
            console.error('DTS Client: Failed to load server list:', error);
            // Add a default option indicating no servers available
            serverListSelect.innerHTML = '<option value="">No servers available</option>';
        }
    }

    /**
     * Populate the server list select element
     */
    function populateServerList(servers) {
        // Clear existing options
        serverListSelect.innerHTML = '';
        
        // Add default option
        const defaultOption = document.createElement('option');
        defaultOption.value = '';
        defaultOption.textContent = 'Select a DTS server...';
        serverListSelect.appendChild(defaultOption);
        
        // Add server options
        servers.forEach(server => {
            const option = document.createElement('option');
            option.value = server.entry;
            option.textContent = server.title;
            serverListSelect.appendChild(option);
        });
    }

    /**
     * Connect to DTS Entry Endpoint and display server information
     */
    async function connectToDTS() {
        // Get server URL from the dropdown selection
        const serverUrl = serverListSelect.value;
        
        if (!serverUrl) {
            displayError('Please select a server from the dropdown');
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
            <p><strong>Documents Endpoint:</strong> <a href="${data.document || '#'}" target="_blank">${data.documents || 'N/A'}</a></p>
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
     * Generate action buttons based on supported media types
     */
    function generateActionButtons(member) {
        const mediaTypes = member.mediaTypes || [];
        let buttons = '';
        
        // Default XML/TEI button
        buttons += `<button class="dts-action-btn view-document" data-media-type="application/tei+xml" title="View as TEI/XML">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-filetype-xml" viewBox="0 0 16 16">
                <path fill-rule="evenodd" d="M14 4.5V14a2 2 0 0 1-2 2v-1a1 1 0 0 0 1-1V4.5h-2A1.5 1.5 0 0 1 9.5 3V1H4a1 1 0 0 0-1 1v9H2V2a2 2 0 0 1 2-2h5.5zM3.527 11.85h-.893l-.823 1.439h-.036L.943 11.85H.012l1.227 1.983L0 15.85h.861l.853-1.415h.035l.85 1.415h.908l-1.254-1.992zm.954 3.999v-2.66h.038l.952 2.159h.516l.946-2.16h.038v2.661h.715V11.85h-.8l-1.14 2.596h-.025L4.58 11.85h-.806v3.999zm4.71-.674h1.696v.674H8.4V11.85h.791z"/>
            </svg>
        </button>`;
        
        // Check for PDF support
        const hasPdfLatex = mediaTypes.includes('application/pdf; media=latex');
        const hasPdfFo = mediaTypes.includes('application/pdf; media=fo');
        
        if (hasPdfLatex || hasPdfFo) {
            const pdfMediaType = hasPdfLatex ? 'application/pdf; media=latex' : 'application/pdf; media=fo';
            buttons += `<button class="dts-action-btn view-document" data-media-type="${pdfMediaType}" title="Download as PDF">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-file-earmark-pdf" viewBox="0 0 16 16">
                    <path d="M14 14V4.5L9.5 0H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2zM9.5 3A1.5 1.5 0 0 0 11 4.5h2V14a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h5.5v2z"/>
                    <path d="M4.603 14.087a.81.81 0 0 1-.438-.42c-.195-.388-.13-.776.08-1.102.198-.307.526-.568.897-.787a7.68 7.68 0 0 1 1.482-.645 19.697 19.697 0 0 0 1.062-2.227 7.269 7.269 0 0 1-.43-1.295c-.086-.4-.119-.796-.046-1.136.075-.354.274-.672.65-.823.192-.077.4-.12.602-.077a.7.7 0 0 1 .477.365c.088.164.12.356.127.538.007.188-.012.396-.047.614-.084.51-.27 1.134-.52 1.794a10.954 10.954 0 0 0 .98 1.686 5.753 5.753 0 0 1 1.334.05c.364.066.734.195.96.465.12.144.193.32.2.518.007.192-.047.382-.138.563a1.04 1.04 0 0 1-.354.416.856.856 0 0 1-.51.138c-.331-.014-.654-.196-.933-.417a5.716 5.716 0 0 1-.911-.95 11.651 11.651 0 0 0-1.997.406 11.307 11.307 0 0 1-1.02 1.51c-.292.35-.609.656-.927.787a.793.793 0 0 1-.58.029zm1.379-1.901c-.166.076-.32.156-.459.238-.328.194-.541.383-.647.547-.094.145-.096.25-.04.361.01.022.02.036.026.044a.266.266 0 0 0 .035-.012c.137-.056.355-.235.635-.572a8.18 8.18 0 0 0 .45-.606zm1.64-1.33a12.71 12.71 0 0 1 1.01-.193 11.744 11.744 0 0 1-.51-.858 20.801 20.801 0 0 1-.5 1.05zm2.446.45c.15.163.296.3.435.41.24.19.407.253.498.256a.107.107 0 0 0 .07-.015.307.307 0 0 0 .094-.125.436.436 0 0 0 .059-.2.095.095 0 0 0-.026-.063c-.052-.062-.2-.152-.518-.209a3.876 3.876 0 0 0-.612-.053zM8.078 7.8a6.7 6.7 0 0 0 .2-.828c.031-.188.043-.343.038-.465a.613.613 0 0 0-.032-.198.517.517 0 0 0-.145.04c-.087.035-.158.106-.196.283-.04.192-.03.469.046.791.024.081.047.158.068.245z"/>
                </svg>
            </button>`;
        }
        
        // Check for EPUB support
        if (mediaTypes.includes('application/epub+zip; media=epub')) {
            buttons += `<button class="dts-action-btn view-document" data-media-type="application/epub+zip; media=epub" title="Download as EPUB">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-book" viewBox="0 0 16 16">
                    <path d="M1 2.828c.885-.37 2.154-.769 3.388-.893 1.33-.134 2.458.063 3.112.752v9.746c-.935-.53-2.12-.603-3.213-.493-1.18.12-2.37.461-3.287.811V2.828zm7.5-.141c.654-.689 1.782-.886 3.112-.752 1.234.124 2.503.523 3.388.893v9.923c-.918-.35-2.107-.692-3.287-.81-1.094-.111-2.278-.039-3.213.492V2.687zM8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-3.994 1.105A.5.5 0 0 0 0 2.5v11a.5.5 0 0 0 .707.455c.882-.4 2.303-.881 3.68-1.02 1.409-.142 2.59.087 3.223.877a.5.5 0 0 0 .78 0c.633-.79 1.814-1.019 3.222-.877 1.378.139 2.8.62 3.681 1.02A.5.5 0 0 0 16 13.5v-11a.5.5 0 0 0-.293-.455c-.952-.433-2.48-.952-3.994-1.105C10.413.809 8.985.936 8 1.783z"/>
                </svg>
            </button>`;
        }
        
        // Check for HTML support
        const hasHtmlWeb = mediaTypes.includes('text/html; charset=utf-8');
        const hasHtmlPrint = mediaTypes.includes('text/html; charset=utf-8; media=print');
        
        if (hasHtmlWeb || hasHtmlPrint) {
            const htmlMediaType = hasHtmlWeb ? 'text/html; charset=utf-8' : 'text/html; charset=utf-8; media=print';
            const htmlTitle = hasHtmlWeb ? 'View as HTML' : 'View as HTML (Print)';
            buttons += `<button class="dts-action-btn view-document" data-media-type="${htmlMediaType}" title="${htmlTitle}">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-file-earmark-code" viewBox="0 0 16 16">
                    <path d="M14 4.5V14a2 2 0 0 1-2 2v-1a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h5.5v2z"/>
                    <path d="M9.5 3A1.5 1.5 0 0 0 11 4.5h2V14a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h5.5v2z"/>
                    <path d="M8.646 6.646a.5.5 0 0 1 .708 0l2 2a.5.5 0 0 1 0 .708l-2 2a.5.5 0 0 1-.708-.708L10.293 9 8.646 7.354a.5.5 0 0 1 0-.708zm-1.292 0a.5.5 0 0 0-.708 0l-2 2a.5.5 0 0 0 0 .708l2 2a.5.5 0 0 0 .708-.708L5.707 9l1.647-1.646a.5.5 0 0 0 0-.708z"/>
                </svg>
            </button>`;
        }
        
        return buttons;
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
                
                // Generate action buttons for documents only
                const actionButtons = isCollection ? '' : generateActionButtons(member);
                
                tableBody += `
                    <tr>
                        <td><span class="member-type ${isCollection ? 'collection' : 'document'}">${memberType}</span></td>
                        <td>
                            <strong class="dts-title-clickable">${memberTitle}</strong><br>
                            <code>${memberId}</code>
                        </td>
                        <td>${actionButtons}</td>
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
            displayError(`Failed to fetch document metadata: ${error.message}`);
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
        const dublinCore = resource.dublinCore || {};

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

        // Generate metadata items for all non-null dublinCore fields
        const metadataItems = Object.entries(dublinCore)
            .filter(([key, value]) => value !== null && value !== undefined && value !== '')
            .map(([key, value]) => `
                <div class="metadata-item">
                    <strong>${key.charAt(0).toUpperCase() + key.slice(1)}:</strong> ${value}
                </div>
            `).join('');

        asideElement.innerHTML = `
            <div class="dts-document-metadata">
                <h3>Document Information</h3>
                <div class="metadata-item">
                    <strong>Title:</strong> ${title}
                </div>
                ${metadataItems}
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
        navigationResponseElement.querySelector('summary').textContent = 'RAW JSON Response';
        navigationResponseElement.open = false; // Keep it collapsed by default
    }


    /**
     * Add click handlers for document action buttons
     */
    function addDocumentActionHandlers(collectionData) {
        const actionButtons = collectionTable.querySelectorAll('.dts-action-btn.view-document');
        actionButtons.forEach((button) => {
            // Find the parent row to get the member index
            const row = button.closest('tr');
            if (!row) return;
            
            // Get all rows in the table body
            const rows = collectionTable.querySelectorAll('tbody tr');
            const rowIndex = Array.from(rows).indexOf(row);
            
            // Get the member data from the current collection data
            const member = collectionData.member[rowIndex];
            if (!member) return;
            
            const memberId = member['@id'] || member.id || '';
            const memberDocumentUrl = member.document || '';
            const mediaType = button.getAttribute('data-media-type') || 'application/tei+xml';
            
            button.addEventListener('click', function() {
                // For documents, open in new tab using the document URL with media type
                if (memberDocumentUrl) {
                    viewDocument(memberId, memberDocumentUrl, mediaType);
                } else {
                    console.error('DTS Client: No document URL available for member:', memberId);
                }
            });
        });
    }

    /**
     * View a document in a new tab
     */
    function viewDocument(documentId, documentUrl, mediaType = 'application/tei+xml') {
        if (!documentUrl) {
            console.error('DTS Client: No document URL provided');
            return;
        }

        try {
            // Expand the URI template to get the actual document URL with media type
            const expandedUrl = expandUriTemplate(documentUrl, { 
                resource: documentId, 
                mediaType: mediaType 
            });
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
