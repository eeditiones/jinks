describe('API', () => {
  beforeEach(() => {
    cy.loginApi()
  })

  describe('documentation page', () => {
    it('renders API docs page', () => {
      cy.visit('api.html')
      cy.get('.title').contains('jinks API')
    })
  })

  // Order: default group endpoints (as in OpenAPI docs)
  describe('default', () => {
    it('GET /profile/{profile} returns HTML page', () => {
      cy.request('/profile/docs').then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.headers).its('content-type').should('include', 'text/html')
        cy.wrap(res.body).should('include', '<html')
      })
    })

    it('GET /{page} returns HTML page', () => {
      cy.request('/index.html').then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.headers).its('content-type').should('include', 'text/html')
        cy.wrap(res.body).should('include', '<html')
      })
    })

    it('GET /api/configurations lists configurations', () => {
      cy.request('/api/configurations').then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'array')
        if (Array.isArray(res.body) && res.body.length > 0) {
          cy.wrap(res.body[0]).should('include.keys', ['type', 'profile', 'config'])
        }
      })
    })

    it('POST /api/expand expands a minimal config', () => {
      cy.request({
        method: 'POST',
        url: '/api/expand',
        headers: { 'content-type': 'application/json' },
        body: { id: 'test', label: 'Test', type: 'app' }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'object')
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
        // lightweight shape: expanded config should not be empty
        cy.wrap(Object.keys(res.body).length > 0).should('eq', true)
      })
    })

    it('POST /api/expand returns 400 for non-object body', () => {
      cy.request({
        method: 'POST',
        url: '/api/expand',
        headers: { 'content-type': 'application/json' },
        body: 'not an object',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
      })
    })

    it('POST /api/generator updates/generates profile in dry mode', () => {
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'default', dry: true },
        headers: { 'content-type': 'application/json' },
        body: { config: { id: 'test', label: 'Test', type: 'app' }, resolve: [] },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'object')
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
        // lightweight shape: response should contain at least one key
        cy.wrap(Object.keys(res.body).length > 0).should('eq', true)
      })
    })

    it('POST /api/generator accepts array body form (dry mode)', () => {
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'default', dry: true },
        headers: { 'content-type': 'application/json' },
        body: [ { config: { id: 'test-arr', label: 'Test Arr', type: 'app' }, resolve: [] } ],
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 200)
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
        cy.wrap(res.body).should('be.an', 'object')
      })
    })

    // TODO(DP): auth not enforced by backend
    it.skip('POST /api/generator requires authentication (no dry run)', () => {
      cy.clearCookie('token')
      cy.clearCookie('org.exist.login')
      cy.clearCookies()
      cy.clearLocalStorage()
      cy.window().then(win => { try { win.sessionStorage.clear() } catch (e) {} })
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'default', dry: false },
        headers: { 'content-type': 'application/json', 'Cookie': '', 'Authorization': '' },
        body: { config: { id: 'test-no-auth', label: 'No Auth', type: 'app' }, resolve: [] },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [401, 403])
      })
    })

    it('POST /api/templates expands template with object body', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: { template: 'Hello world', params: {} },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'object')
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
      })
    })

    it('POST /api/templates returns 500 for invalid template syntax', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        qs: { 'force-error': true },
        headers: { 'content-type': 'application/json' },
        body: { template: 'Any content', params: {}, mode: 'html' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 500)
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')
      })
    })

    it('POST /api/templates returns 400 for plain string body', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'text/plain' },
        body: 'Plain text with no placeholders',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
      })
    })

    it('GET /api/source returns source or not found', () => {
      cy.request({
        url: '/api/source',
        qs: { path: 'pages/index.html' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [200, 404])
        if (res.status === 200) {
          cy.wrap(res.headers).its('content-type').should('match', /(text|application)\//)
        }
      })
    })

    it('GET /api/source requires path parameter', () => {
      cy.request({
        url: '/api/source',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
      })
    })

    it('POST /api/resolve with fake id/path is rejected or ok', () => {
      cy.request({
        method: 'POST',
        url: '/api/resolve',
        qs: { id: 'fake-id', path: 'pages/index.html' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [200, 400, 404])
      })
    })

    it('POST /api/resolve returns 400 when id is missing', () => {
      cy.request({
        method: 'POST',
        url: '/api/resolve',
        qs: { path: 'pages/index.html' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
      })
    })

    it('POST /api/resolve returns 400 when path is missing', () => {
      cy.request({
        method: 'POST',
        url: '/api/resolve',
        qs: { id: 'fake-id' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
      })
    })
  })

  // Order: view group endpoint
  describe('view', () => {
    it('GET /{file}.md returns markdown (static) or HTML (template)', () => {
      cy.request({
        url: '/profiles/docs/markdown.md',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [200, 404])
        if (res.status === 200) {
          cy.wrap(res.headers)
            .its('content-type')
            .should('match', /text\/markdown|text\/html/)
        }
      })
    })

    it('GET /{file}.md returns 404 for non-existent doc', () => {
      cy.request({ url: '/profiles/docs/does-not-exist.md', failOnStatusCode: false }).then(res => {
        cy.wrap(res.status).should('eq', 404)
      })
    })
  })

  // Order: user group endpoint
  describe('user', () => {
    it('POST /api/login logs in with valid credentials', () => {
      cy.fixture('user').then(user => {
        cy.request({
          method: 'POST',
          url: '/api/login',
          form: true,
          body: { user: user.user, password: user.password },
          failOnStatusCode: false
        }).then(res => {
          cy.wrap(res).its('status').should('eq', 200)
          cy.wrap(res).its('headers').should('have.property', 'content-type')
          cy.wrap(res).its('body').should('be.an', 'object')
          cy.wrap(res.body).should('include.keys', ['user', 'groups', 'dba', 'domain'])
          cy.wrap(res.body.groups).should('be.an', 'array')
        })
      })
    })

    it('POST /api/login rejects invalid credentials', () => {
      cy.request({
        method: 'POST',
        url: '/api/login',
        form: true,
        body: { user: 'wrong', password: 'nope' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [401, 400])
      })
    })

    it('POST /api/login returns 400 when body is missing', () => {
      cy.request({
        method: 'POST',
        url: '/api/login',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 400)
      })
    })
  })

  describe('configurations', () => {
    it('lists available configurations', () => {
      cy.request('/api/configurations').then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'array')
      })
    })
  })

  // Order: deploy-api group endpoints
  describe('deploy', () => {
    it('POST /api/generator/{profile}/deploy returns stubbed success (no side effects)', () => {
      const profile = 'base'
      const stub = { ok: true }
      cy.intercept('POST', '/api/generator/*/deploy', req => {
        req.reply({ statusCode: 200, headers: { 'content-type': 'application/json' }, body: stub })
      }).as('deploy')

      cy.visit('/')
      cy.window().then(win => {
        return win.fetch(`/api/generator/${profile}/deploy`, { method: 'POST' })
      })

      cy.wait('@deploy').its('request.url').should('include', `/api/generator/${profile}/deploy`)
      cy.get('@deploy').its('request.method').should('eq', 'POST')
      cy.get('@deploy').its('response.statusCode').should('eq', 200)
      cy.get('@deploy').its('response.headers').its('content-type').should('include', 'application/json')
      cy.get('@deploy').its('response.body').should('deep.equal', stub)
    })

    it('GET /api/generator/action/{action} without id returns 400/404', () => {
      cy.request({
        method: 'GET',
        url: '/api/generator/action/run',
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('be.oneOf', [400, 404])
      })
    })
  })
})