/**
 * DTS Client - Distributed Text Services API Client (DTS 1.0)
 * Handles connection to DTS Entry Endpoint and displays server information.
 * @see https://dtsapi.org/specifications/versions/v1.0/
 */

function initializeDTSClient() {
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

    if (!connectButton || !serverListSelect || !serverInfoDiv || !collectionTable || !rawResponseDetails || !rawJsonCode) {
        console.error('DTS Client: Core elements not found in DOM');
        return;
    }
    if (!paginationNav || !paginationFirst || !paginationPrevious || !paginationInfo || !paginationNext || !paginationLast) {
        console.error('DTS Client: Pagination elements not found in DOM');
        return;
    }
    if (!breadcrumbsNav || !breadcrumbsList) {
        console.error('DTS Client: Breadcrumbs elements not found in DOM');
        return;
    }

    let serverConfig = null;
    const dtsConfig = readDTSConfig();

    // Collection navigation state — history entries are { id, title, url }
    let currentCollectionId = null;
    let currentCollectionTitle = null;
    let currentCollectionUrl = null;
    let collectionHistory = [];
    let collectionUriTemplate = null;

    // Pagination state
    let currentPagination = null;
    let currentPage = 1;

    connectButton.addEventListener('click', function() {
        connectToDTS();
    });

    // Auto-connect when the user changes the server dropdown
    serverListSelect.addEventListener('change', function() {
        if (serverListSelect.value) connectToDTS();
    });

    paginationFirst.addEventListener('click', () => navigateToPage(1));
    paginationPrevious.addEventListener('click', () => navigateToPage(currentPage - 1));
    paginationNext.addEventListener('click', () => navigateToPage(currentPage + 1));
    paginationLast.addEventListener('click', () => navigateToPage(getLastPageNumber()));

    loadDTSServers();

    function readDTSConfig() {
        const el = document.getElementById('dts-config');
        if (!el || el.getAttribute('type') !== 'application/json') return {};
        try {
            return JSON.parse(el.textContent || '{}');
        } catch (e) {
            console.warn('DTS Client: Invalid #dts-config JSON', e);
            return {};
        }
    }

    function getDTSListUrl(relativePath) {
        const base = (dtsConfig['base-path'] || '').replace(/\/+$/, '');
        const path = (relativePath || '').replace(/^\/+/, '');
        return base ? `${base}/${path}` : path || '';
    }

    async function loadDTSServers() {
        const listUrl = getDTSListUrl('api/dts/list');
        try {
            const response = await fetch(listUrl, { method: 'GET', headers: { 'Accept': 'application/json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            const servers = await response.json();
            populateServerList(servers);
        } catch (error) {
            console.error('DTS Client: Failed to load server list:', error);
            serverListSelect.innerHTML = '<option value="">No servers available</option>';
        }
    }

    function populateServerList(servers) {
        serverListSelect.innerHTML = '';

        const defaultOption = document.createElement('option');
        defaultOption.value = '';
        defaultOption.textContent = 'Select a DTS server...';
        serverListSelect.appendChild(defaultOption);

        const seen = new Set();
        const addOption = (server) => {
            const entry = server?.entry;
            if (!entry || seen.has(entry)) return;
            seen.add(entry);
            const option = document.createElement('option');
            option.value = entry;
            option.textContent = server.title ?? entry;
            serverListSelect.appendChild(option);
        };

        const configServers = Array.isArray(dtsConfig.servers) ? dtsConfig.servers : [];
        configServers.forEach(addOption);
        (Array.isArray(servers) ? servers : []).forEach(addOption);

        // Auto-select and connect if there is exactly one server
        const realOptions = Array.from(serverListSelect.options).filter(o => o.value);
        if (realOptions.length === 1) {
            serverListSelect.value = realOptions[0].value;
            connectToDTS();
        }
    }

    async function connectToDTS() {
        const serverUrl = serverListSelect.value;
        if (!serverUrl) {
            displayError('Please select a server from the dropdown');
            return;
        }

        setLoadingState(true);
        clearServerInfo();
        clearRawResponse();

        // Hide welcome state on first connect
        const welcomeDiv = document.getElementById('dts-welcome');
        if (welcomeDiv) welcomeDiv.hidden = true;

        try {
            const response = await fetch(serverUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            const data = await response.json();
            serverConfig = data;
            displayServerInfo(data);
            displayRawResponse(data, 'Entry Endpoint');
            await fetchRootCollection();
        } catch (error) {
            console.error('DTS Client Error:', error);
            displayError(`Failed to connect to DTS server: ${error.message}`);
        } finally {
            setLoadingState(false);
        }
    }

    function displayServerInfo(data) {
        const documentUrl = data.document ?? data.documents ?? '#';
        const dtsVersion = data.dtsVersion ? `<p><strong>DTS Version:</strong> ${data.dtsVersion}</p>` : '';
        serverInfoDiv.innerHTML = `
            ${dtsVersion}
            <details>
                <summary>Endpoints</summary>
                <p><strong>Collection:</strong> <a href="${data.collection || '#'}" target="_blank">${data.collection || 'N/A'}</a></p>
                <p><strong>Document:</strong> <a href="${documentUrl}" target="_blank">${documentUrl === '#' ? 'N/A' : documentUrl}</a></p>
                <p><strong>Navigation:</strong> <a href="${data.navigation || '#'}" target="_blank">${data.navigation || 'N/A'}</a></p>
            </details>
        `;
    }

    function displayError(message) {
        serverInfoDiv.innerHTML = `<div class="dts-error"><strong>Error:</strong> ${message}</div>`;
    }

    function clearServerInfo() {
        serverInfoDiv.innerHTML = '';
    }

    async function fetchRootCollection() {
        if (!serverConfig || !serverConfig.collection) {
            console.error('DTS Client: No server configuration or collection URL available');
            return;
        }

        try {
            clearCollectionTable();
            hideDocumentAside();
            currentCollectionId = null;
            currentCollectionTitle = null;
            currentCollectionUrl = null;
            collectionHistory = [];
            collectionUriTemplate = serverConfig.collection;
            currentPagination = null;
            currentPage = 1;
            hidePagination();

            const rootCollectionUrl = expandUriTemplate(serverConfig.collection, {});
            const response = await fetch(rootCollectionUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);

            const collectionData = await response.json();
            const rootTitle = resolveDublinCoreValue(collectionData.title) || 'Root Collection';
            displayCollectionTable(collectionData, rootTitle);
            displayRawResponse(collectionData, rootTitle);
            handlePagination(collectionData);

        } catch (error) {
            console.error('DTS Collection Error:', error);
            displayCollectionError(`Failed to fetch collection: ${error.message}`);
        }
    }

    /**
     * Generate action buttons — HTML first for user-friendliness, then TEI/XML, PDF, EPUB.
     */
    function generateActionButtons(member) {
        const mediaTypes = member.mediaTypes || [];
        let buttons = '<span role="group" class="dts-action-group">';

        // HTML (most user-friendly — show first)
        const hasHtmlWeb = mediaTypes.includes('text/html; charset=utf-8');
        const hasHtmlPrint = mediaTypes.includes('text/html; charset=utf-8; media=print');
        if (hasHtmlWeb || hasHtmlPrint) {
            const htmlMediaType = hasHtmlWeb ? 'text/html; charset=utf-8' : 'text/html; charset=utf-8; media=print';
            buttons += `<button class="dts-action-btn view-document" data-media-type="${htmlMediaType}" data-tooltip="View as HTML">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-filetype-html" viewBox="0 0 16 16">
                    <path fill-rule="evenodd" d="M14 4.5V11h-1V4.5h-2A1.5 1.5 0 0 1 9.5 3V1H4a1 1 0 0 0-1 1v9H2V2a2 2 0 0 1 2-2h5.5zm-9.736 7.35v3.999h-.791v-1.714H1.79v1.714H1V11.85h.791v1.626h1.682V11.85h.79Zm2.251.662v3.337h-.794v-3.337H4.588v-.662h3.064v.662zm2.176 3.337v-2.66h.038l.952 2.159h.516l.946-2.16h.038v2.661h.715V11.85h-.8l-1.14 2.596H9.93L8.79 11.85h-.805v3.999zm4.71-.674h1.696v.674H12.61V11.85h.79v3.325Z"/>
                </svg></button>`;
        }

        // TEI/XML
        const defaultTeiType = mediaTypes.includes('application/tei+xml') ? 'application/tei+xml' : 'application/xml';
        buttons += `<button class="dts-action-btn view-document" data-media-type="${defaultTeiType}" data-tooltip="View as TEI/XML">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-filetype-xml" viewBox="0 0 16 16">
                <path fill-rule="evenodd" d="M14 4.5V14a2 2 0 0 1-2 2v-1a1 1 0 0 0 1-1V4.5h-2A1.5 1.5 0 0 1 9.5 3V1H4a1 1 0 0 0-1 1v9H2V2a2 2 0 0 1 2-2h5.5zM3.527 11.85h-.893l-.823 1.439h-.036L.943 11.85H.012l1.227 1.983L0 15.85h.861l.853-1.415h.035l.85 1.415h.908l-1.254-1.992zm.954 3.999v-2.66h.038l.952 2.159h.516l.946-2.16h.038v2.661h.715V11.85h-.8l-1.14 2.596h-.025L4.58 11.85h-.806v3.999zm4.71-.674h1.696v.674H8.4V11.85h.791z"/>
            </svg></button>`;

        // PDF
        const hasPdfLatex = mediaTypes.includes('application/pdf; media=latex');
        const hasPdfFo = mediaTypes.includes('application/pdf; media=fo');
        if (hasPdfLatex || hasPdfFo) {
            const pdfMediaType = hasPdfLatex ? 'application/pdf; media=latex' : 'application/pdf; media=fo';
            buttons += `<button class="dts-action-btn view-document" data-media-type="${pdfMediaType}" data-tooltip="Download as PDF">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-filetype-pdf" viewBox="0 0 16 16">
                    <path fill-rule="evenodd" d="M14 4.5V14a2 2 0 0 1-2 2h-1v-1h1a1 1 0 0 0 1-1V4.5h-2A1.5 1.5 0 0 1 9.5 3V1H4a1 1 0 0 0-1 1v9H2V2a2 2 0 0 1 2-2h5.5zM1.6 11.85H0v3.999h.791v-1.342h.803q.43 0 .732-.173.305-.175.463-.474a1.4 1.4 0 0 0 .161-.677q0-.375-.158-.677a1.2 1.2 0 0 0-.46-.477q-.3-.18-.732-.179m.545 1.333a.8.8 0 0 1-.085.38.57.57 0 0 1-.238.241.8.8 0 0 1-.375.082H.788V12.48h.66q.327 0 .512.181.185.183.185.522m1.217-1.333v3.999h1.46q.602 0 .998-.237a1.45 1.45 0 0 0 .595-.689q.196-.45.196-1.084 0-.63-.196-1.075a1.43 1.43 0 0 0-.589-.68q-.396-.234-1.005-.234zm.791.645h.563q.371 0 .609.152a.9.9 0 0 1 .354.454q.118.302.118.753a2.3 2.3 0 0 1-.068.592 1.1 1.1 0 0 1-.196.422.8.8 0 0 1-.334.252 1.3 1.3 0 0 1-.483.082h-.563zm3.743 1.763v1.591h-.79V11.85h2.548v.653H7.896v1.117h1.606v.638z"/>
                </svg></button>`;
        }

        // EPUB
        if (mediaTypes.includes('application/epub+zip; media=epub')) {
            buttons += `<button class="dts-action-btn view-document" data-media-type="application/epub+zip; media=epub" data-tooltip="Download as EPUB">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" class="bi bi-book" viewBox="0 0 16 16">
                    <path d="M1 2.828c.885-.37 2.154-.769 3.388-.893 1.33-.134 2.458.063 3.112.752v9.746c-.935-.53-2.12-.603-3.213-.493-1.18.12-2.37.461-3.287.811zm7.5-.141c.654-.689 1.782-.886 3.112-.752 1.234.124 2.503.523 3.388.893v9.923c-.918-.35-2.107-.692-3.287-.81-1.094-.111-2.278-.039-3.213.492zM8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-3.994 1.105A.5.5 0 0 0 0 2.5v11a.5.5 0 0 0 .707.455c.882-.4 2.303-.881 3.68-1.02 1.409-.142 2.59.087 3.223.877a.5.5 0 0 0 .78 0c.633-.79 1.814-1.019 3.222-.877 1.378.139 2.8.62 3.681 1.02A.5.5 0 0 0 16 13.5v-11a.5.5 0 0 0-.293-.455c-.952-.433-2.48-.952-3.994-1.105C10.413.809 8.985.936 8 1.783"/>
                </svg></button>`;
        }

        return buttons + '</span>';
    }

    function displayCollectionTable(collectionData, collectionTitle = 'Collection') {
        updateBreadcrumbs(collectionTitle);

        const tableHeader = `
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Title</th>
                    <th>Actions</th>
                </tr>
            </thead>
        `;

        let tableBody = '<tbody>';

        if (collectionData.member && Array.isArray(collectionData.member)) {
            collectionData.member.forEach(member => {
                const memberType = member['@type'] || 'Unknown';
                const memberTitle = resolveDublinCoreValue(member.title) || member.label || 'Untitled';
                const memberId = member['@id'] || member.id || '';
                const rawDesc = resolveDublinCoreValue(member.description || member?.dublinCore?.description);
                const memberDesc = rawDesc && rawDesc.length > 120 ? rawDesc.slice(0, 120) + '…' : rawDesc;
                const isCollection = memberType.toLowerCase().includes('collection');
                const actionButtons = isCollection ? '' : generateActionButtons(member);

                tableBody += `
                    <tr>
                        <td><span class="badge ${isCollection ? 'collection' : 'document'}">${isCollection ? 'Collection' : 'Document'}</span></td>
                        <td>
                            <strong class="dts-title-clickable">${memberTitle}</strong><br>
                            <code>${memberId}</code>
                            ${memberDesc ? `<br><small class="member-description">${memberDesc}</small>` : ''}
                        </td>
                        <td>${actionButtons}</td>
                    </tr>
                `;
            });
        } else {
            tableBody += '<tr><td colspan="3">No collection members found</td></tr>';
        }

        tableBody += '</tbody>';
        collectionTable.innerHTML = tableHeader + tableBody;

        addTitleClickHandlers(collectionData);
        addDocumentActionHandlers(collectionData);
    }

    function addTitleClickHandlers(collectionData) {
        const titleElements = collectionTable.querySelectorAll('.dts-title-clickable');
        titleElements.forEach((titleElement, index) => {
            const member = collectionData.member[index];
            if (!member) return;

            const memberType = member['@type'] || 'Unknown';
            const memberId = member['@id'] || member.id || '';
            const memberTitle = resolveDublinCoreValue(member.title) || member.label || 'Untitled';
            const memberCollectionUrl = member.collection || '';
            const memberNavigationUrl = member.navigation || '';
            const isCollection = memberType.toLowerCase().includes('collection');

            titleElement.addEventListener('click', function() {
                if (isCollection) {
                    if (memberCollectionUrl) {
                        navigateToCollection(memberId, memberTitle, memberCollectionUrl);
                    } else {
                        console.error('DTS Client: No collection URL available for member:', memberId);
                    }
                } else {
                    if (memberNavigationUrl) {
                        fetchDocumentMetadata(memberId, memberNavigationUrl);
                    } else {
                        console.error('DTS Client: No navigation URL available for member:', memberId);
                    }
                }
            });
        });
    }

    async function fetchDocumentMetadata(documentId, navigationUrlTemplate) {
        if (!navigationUrlTemplate) {
            console.error('DTS Client: No navigation URL template provided');
            return;
        }

        try {
            const expandedUrl = expandUriTemplate(navigationUrlTemplate, { resource: documentId, down: 2 });
            const response = await fetch(expandedUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);

            const navigationData = await response.json();
            displayDocumentStructure(navigationData);
            displayRawResponse(navigationData, 'Navigation Endpoint');

        } catch (error) {
            console.error('DTS Navigation Error:', error);
            displayError(`Failed to fetch document metadata: ${error.message}`);
        }
    }

    function resolveDublinCoreValue(value) {
        if (value == null || value === '') return '';
        if (Array.isArray(value)) {
            const first = value[0];
            if (first && typeof first === 'object' && 'value' in first) return first.value;
            if (typeof first === 'string') return first;
            return '';
        }
        return String(value);
    }

    function displayDocumentStructure(navigationData) {
        const asideElement = document.getElementById('dts-aside');
        if (!asideElement) return;

        const resource = navigationData.resource || {};
        const members = navigationData.member || [];
        const title = resolveDublinCoreValue(resource.title) || 'Unknown Title';
        const dublinCore = resource.dublinCore || {};

        window.currentDocumentUrlTemplate = resource.document;

        const citableUnits = members.filter(member => member['@type'] === 'CitableUnit');

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

        const metadataItems = Object.entries(dublinCore)
            .filter(([, value]) => value !== null && value !== undefined && value !== '')
            .map(([key, value]) => {
                const displayValue = resolveDublinCoreValue(value);
                if (!displayValue) return '';
                return `<div class="metadata-item"><strong>${key.charAt(0).toUpperCase() + key.slice(1)}:</strong> ${displayValue}</div>`;
            }).filter(Boolean).join('');

        asideElement.hidden = false;
        asideElement.innerHTML = `
            <div class="dts-document-metadata">
                <h3>Document Information</h3>
                <div class="metadata-item"><strong>Title:</strong> ${title}</div>
                ${metadataItems}
                ${structureHtml}
            </div>
        `;
    }

    function buildHierarchicalStructure(citableUnits) {
        const unitsByLevel = {};
        citableUnits.forEach(unit => {
            const level = unit.level || 1;
            if (!unitsByLevel[level]) unitsByLevel[level] = [];
            unitsByLevel[level].push(unit);
        });

        const levels = Object.keys(unitsByLevel).map(Number).sort((a, b) => a - b);
        if (levels.length === 0) return '<p>No structure information available</p>';
        return buildLevelStructure(unitsByLevel, levels, 0, citableUnits);
    }

    function buildLevelStructure(unitsByLevel, levels, levelIndex, allUnits) {
        if (levelIndex >= levels.length) return '';

        const currentLevel = levels[levelIndex];
        const currentUnits = unitsByLevel[currentLevel] || [];
        if (currentUnits.length === 0) return buildLevelStructure(unitsByLevel, levels, levelIndex + 1, allUnits);

        let html = '';
        currentUnits.forEach(unit => {
            const title = resolveDublinCoreValue(unit.dublinCore?.title) || 'Untitled';
            const identifier = unit.identifier || '';
            const children = allUnits.filter(child => child.level > currentLevel && child.parent === identifier);

            if (children.length > 0) {
                const childrenHtml = buildLevelStructure(unitsByLevel, levels, levelIndex + 1, allUnits);
                html += `
                    <details class="structure-details level-${currentLevel}">
                        <summary class="structure-summary">
                            <span class="structure-title">${title}</span>
                            ${identifier ? `<span class="structure-identifier" onclick="requestDocumentFragment('${identifier}')" title="Click to view fragment">${identifier}</span>` : ''}
                        </summary>
                        <div class="structure-children">${childrenHtml}</div>
                    </details>
                `;
            } else {
                html += `
                    <div class="structure-item level-${currentLevel}">
                        <span class="structure-title">${title}</span>
                        ${identifier ? `<span class="structure-identifier" onclick="requestDocumentFragment('${identifier}')" title="Click to view fragment">${identifier}</span>` : ''}
                    </div>
                `;
            }
        });
        return html;
    }

    function addDocumentActionHandlers(collectionData) {
        const actionButtons = collectionTable.querySelectorAll('.dts-action-btn.view-document');
        actionButtons.forEach((button) => {
            const row = button.closest('tr');
            if (!row) return;
            const rows = collectionTable.querySelectorAll('tbody tr');
            const rowIndex = Array.from(rows).indexOf(row);
            const member = collectionData.member[rowIndex];
            if (!member) return;

            const memberId = member['@id'] || member.id || '';
            const memberDocumentUrl = member.document || '';
            const mediaType = button.getAttribute('data-media-type') || 'application/tei+xml';

            button.addEventListener('click', function() {
                if (memberDocumentUrl) {
                    viewDocument(memberId, memberDocumentUrl, mediaType);
                } else {
                    console.error('DTS Client: No document URL available for member:', memberId);
                }
            });
        });
    }

    function viewDocument(documentId, documentUrl, mediaType = 'application/tei+xml') {
        if (!documentUrl) return;
        try {
            const expandedUrl = expandUriTemplate(documentUrl, { resource: documentId, mediaType: mediaType });
            window.open(expandedUrl, '_blank');
        } catch (error) {
            console.error('DTS Client: Error opening document:', error);
        }
    }

    window.requestDocumentFragment = function(identifier) {
        if (!window.currentDocumentUrlTemplate || !identifier) return;
        try {
            const resourceMatch = window.currentDocumentUrlTemplate.match(/resource=([^&{]+)/);
            if (!resourceMatch) return;
            const expandedUrl = expandUriTemplate(window.currentDocumentUrlTemplate, {
                resource: resourceMatch[1],
                ref: identifier,
                mediaType: 'application/tei+xml'
            });
            window.open(expandedUrl, '_blank');
        } catch (error) {
            console.error('DTS Client: Error requesting document fragment:', error);
        }
    };

    /**
     * Navigate into a sub-collection, pushing the current collection onto the history stack.
     */
    async function navigateToCollection(collectionId, collectionTitle, collectionUrl = null) {
        if (!collectionUrl) {
            console.error('DTS Client: No collection URL provided');
            return;
        }

        hideDocumentAside();

        if (currentCollectionId !== null) {
            collectionHistory.push({ id: currentCollectionId, title: currentCollectionTitle, url: currentCollectionUrl });
        }

        currentCollectionId = collectionId;
        currentCollectionTitle = collectionTitle;
        currentCollectionUrl = collectionUrl;

        try {
            const expandedUrl = expandUriTemplate(collectionUrl, {});
            const response = await fetch(expandedUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);

            const collectionData = await response.json();
            const fetchedTitle = resolveDublinCoreValue(collectionData.title) || collectionData.label || collectionTitle;
            currentCollectionTitle = fetchedTitle;
            displayCollectionTable(collectionData, fetchedTitle);
            displayRawResponse(collectionData, fetchedTitle);
            handlePagination(collectionData);

        } catch (error) {
            console.error('DTS Collection Navigation Error:', error);
            displayCollectionError(`Failed to navigate to collection: ${error.message}`);
        }
    }

    function encodeUriValue(value) {
        if (value == null || value === '') return '';
        const s = String(value);
        try {
            return s.includes('%') ? encodeURIComponent(decodeURIComponent(s)) : encodeURIComponent(s);
        } catch (_) {
            return encodeURIComponent(s);
        }
    }

    function expandUriTemplate(template, variables = {}) {
        let url = template;

        Object.keys(variables).forEach(key => {
            const value = encodeUriValue(variables[key]);
            url = url.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
        });

        url = url.replace(/\{&([^}]+)\}/g, (match, params) => {
            const paramList = params.split(',').map(p => p.trim());
            const queryParams = [];
            paramList.forEach(param => {
                if (variables[param] !== undefined) {
                    queryParams.push(`${param}=${encodeUriValue(variables[param])}`);
                }
            });
            return queryParams.length > 0 ? '&' + queryParams.join('&') : '';
        });

        url = url.replace(/\{[^}]+\}/g, '');
        return url;
    }

    function updateBreadcrumbs(currentTitle) {
        breadcrumbsList.innerHTML = '';

        const rootLi = document.createElement('li');
        const rootLink = document.createElement('a');
        rootLink.className = 'dts-breadcrumb-item';
        rootLink.setAttribute('data-action', 'navigate');
        rootLink.setAttribute('data-target', 'root');
        rootLink.href = '#';
        rootLink.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" viewBox="0 0 16 16"><path d="M8.707 1.5a1 1 0 0 0-1.414 0L.646 8.146a.5.5 0 0 0 .708.708L2 8.207V13.5A1.5 1.5 0 0 0 3.5 15h9a1.5 1.5 0 0 0 1.5-1.5V8.207l.646.647a.5.5 0 0 0 .708-.708L13 5.793V2.5a.5.5 0 0 0-.5-.5h-1a.5.5 0 0 0-.5.5v1.293zM13 7.207V13.5a.5.5 0 0 1-.5.5h-9a.5.5 0 0 1-.5-.5V7.207l5-5z"/></svg> Root';
        rootLi.appendChild(rootLink);
        breadcrumbsList.appendChild(rootLi);

        collectionHistory.forEach((entry, index) => {
            const historyLi = document.createElement('li');
            const historyButton = document.createElement('button');
            historyButton.className = 'dts-breadcrumb-item';
            historyButton.setAttribute('data-action', 'navigate');
            historyButton.setAttribute('data-target', 'history');
            historyButton.setAttribute('data-index', index);
            historyButton.textContent = entry.title || `Collection ${index + 1}`;
            historyLi.appendChild(historyButton);
            breadcrumbsList.appendChild(historyLi);
        });

        if (currentCollectionId) {
            const currentLi = document.createElement('li');
            const currentSpan = document.createElement('span');
            currentSpan.className = 'dts-breadcrumb-current';
            currentSpan.textContent = currentTitle;
            currentLi.appendChild(currentSpan);
            breadcrumbsList.appendChild(currentLi);
        }

        addBreadcrumbHandlers();
    }

    function hideDocumentAside() {
        const asideElement = document.getElementById('dts-aside');
        if (asideElement) {
            asideElement.hidden = true;
            asideElement.innerHTML = '';
        }
    }

    async function navigateToRoot() {
        currentCollectionId = null;
        currentCollectionTitle = null;
        currentCollectionUrl = null;
        collectionHistory = [];
        hideDocumentAside();
        await fetchRootCollection();
    }

    /**
     * Navigate back to a collection stored in history at the given index.
     * After navigation, that entry becomes current and everything after it is discarded.
     */
    async function navigateToHistory(index) {
        if (index < 0 || index >= collectionHistory.length) return;
        const target = collectionHistory[index];
        collectionHistory = collectionHistory.slice(0, index);
        currentCollectionId = target.id;
        currentCollectionTitle = target.title;
        currentCollectionUrl = target.url;
        hideDocumentAside();

        try {
            const expandedUrl = expandUriTemplate(target.url, {});
            const response = await fetch(expandedUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            const collectionData = await response.json();
            const fetchedTitle = resolveDublinCoreValue(collectionData.title) || collectionData.label || target.title;
            currentCollectionTitle = fetchedTitle;
            displayCollectionTable(collectionData, fetchedTitle);
            displayRawResponse(collectionData, fetchedTitle);
            handlePagination(collectionData);
        } catch (error) {
            console.error('DTS Collection Navigation Error:', error);
            displayCollectionError(`Failed to navigate: ${error.message}`);
        }
    }

    function addBreadcrumbHandlers() {
        const breadcrumbItems = breadcrumbsList.querySelectorAll('.dts-breadcrumb-item');
        breadcrumbItems.forEach(item => item.replaceWith(item.cloneNode(true)));

        breadcrumbsList.querySelectorAll('.dts-breadcrumb-item').forEach(item => {
            item.addEventListener('click', function(event) {
                event.preventDefault();
                const action = this.getAttribute('data-action');
                const target = this.getAttribute('data-target');
                if (action === 'navigate') {
                    if (target === 'root') {
                        navigateToRoot();
                    } else if (target === 'history') {
                        navigateToHistory(parseInt(this.getAttribute('data-index')));
                    }
                }
            });
        });
    }

    function displayCollectionError(message) {
        collectionTable.innerHTML = `
            <thead><tr><th>Type</th><th>Title</th><th>Actions</th></tr></thead>
            <tbody><tr><td colspan="3" class="error-message"><strong>Error:</strong> ${message}</td></tr></tbody>
        `;
    }

    function clearCollectionTable() {
        collectionTable.innerHTML = '';
    }

    function displayRawResponse(data, requestType = 'API Response') {
        rawJsonCode.textContent = JSON.stringify(data, null, 2);
        rawResponseDetails.querySelector('summary').textContent = `Raw JSON Response (${requestType})`;
        rawResponseDetails.open = false;
    }

    function clearRawResponse() {
        rawJsonCode.textContent = '';
        rawResponseDetails.querySelector('summary').textContent = 'Raw JSON Response';
        rawResponseDetails.open = false;
    }

    function handlePagination(collectionData) {
        if (collectionData.view && collectionData.view['@type'] === 'Pagination') {
            currentPagination = collectionData.view;
            showPagination();
            updatePaginationControls();
        } else {
            hidePagination();
        }
        if (collectionData.collection) {
            collectionUriTemplate = collectionData.collection;
        }
    }

    function showPagination() { paginationNav.style.display = 'block'; }
    function hidePagination() { paginationNav.style.display = 'none'; }

    function updatePaginationControls() {
        if (!currentPagination) { hidePagination(); return; }

        const currentPageNum = extractPageFromUrl(currentPagination['@id']) || 1;
        const firstPageNum = extractPageFromUrl(currentPagination.first) || 1;
        const lastPageNum = extractPageFromUrl(currentPagination.last) || 1;
        const previousPageNum = currentPagination.previous ? extractPageFromUrl(currentPagination.previous) : null;
        const nextPageNum = currentPagination.next ? extractPageFromUrl(currentPagination.next) : null;

        currentPage = currentPageNum;
        paginationFirst.disabled = currentPageNum <= firstPageNum;
        paginationPrevious.disabled = !previousPageNum || currentPageNum <= firstPageNum;
        paginationNext.disabled = !nextPageNum || currentPageNum >= lastPageNum;
        paginationLast.disabled = currentPageNum >= lastPageNum;
        paginationInfo.textContent = `Page ${currentPageNum} of ${lastPageNum}`;
    }

    function extractPageFromUrl(url) {
        if (!url) return null;
        const match = url.match(/[?&]page=(\d+)/);
        return match ? parseInt(match[1]) : null;
    }

    function getLastPageNumber() {
        if (!currentPagination || !currentPagination.last) return 1;
        return extractPageFromUrl(currentPagination.last) || 1;
    }

    async function navigateToPage(pageNumber) {
        if (!currentPagination || !collectionUriTemplate) return;
        if (pageNumber < 1 || pageNumber > getLastPageNumber()) return;

        try {
            const variables = { page: pageNumber };
            if (currentCollectionId) variables.id = currentCollectionId;
            const pageUrl = expandUriTemplate(collectionUriTemplate, variables);

            const response = await fetch(pageUrl, { method: 'GET', headers: { 'Accept': 'application/ld+json' } });
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);

            const collectionData = await response.json();
            const collectionTitle = resolveDublinCoreValue(collectionData.title) || collectionData.label ||
                (currentCollectionId ? `Collection: ${currentCollectionId}` : 'Root Collection');
            displayCollectionTable(collectionData, collectionTitle);
            displayRawResponse(collectionData, `Page ${pageNumber}`);
            handlePagination(collectionData);

        } catch (error) {
            console.error('DTS Pagination Error:', error);
            displayCollectionError(`Failed to navigate to page ${pageNumber}: ${error.message}`);
        }
    }

    function setLoadingState(loading) {
        if (loading) {
            connectButton.disabled = true;
            connectButton.textContent = 'Connecting...';
            collectionTable.classList.add('loading');
        } else {
            connectButton.disabled = false;
            connectButton.textContent = 'Connect';
            collectionTable.classList.remove('loading');
        }
    }
}

document.addEventListener('DOMContentLoaded', initializeDTSClient);
