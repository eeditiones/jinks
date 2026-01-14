describe('API', () => {
  beforeEach(() => {
    cy.loginApi()
  })

  describe('documentation page', () => {
    it('renders API docs page', () => {
      cy.visit('api.html')
      cy.get('.title').contains('jinks API')
      cy.get('.auth-wrapper').should('be.visible')
      cy.get('h3').contains('default')
      cy.get('h3').contains('view')
      cy.get('h3').contains('user')
      cy.get('h3').should('have.length.greaterThan', 3)
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

    it('POST /api/generator updates/generates profile (dry mode)', () => {
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
    // see #104
    it.skip('POST /api/generator requires authentication (no dry run)', () => {
      cy.clearCookie('token')
      cy.clearCookie('JSESSIONID')
      cy.clearCookie('org.exist.login')
      cy.clearCookie('teipublisher.com.login')
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

    it('POST /api/templates returns 200 for valid template with empty params', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: 'Simple template without placeholders',
          params: {},
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body).should('have.property', 'result')
        cy.wrap(res.body.result).should('eq', 'Simple template without placeholders')
      })
    })

    it('POST /api/templates returns 200 for template with variable interpolation', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: 'Hello [[ $name ]]',
          params: { name: 'World' },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body.result).should('include', 'Hello')
        cy.wrap(res.body.result).should('include', 'World')
      })
    })

    it('POST /api/templates returns 200 for template with conditional logic', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: '[% if $show %]Visible[% else %]Hidden[% endif %]',
          params: { show: true },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body.result).should('include', 'Visible')
        cy.wrap(res.body.result).should('not.include', 'Hidden')
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

    // TODO(DP): see #104 
    it('POST /api/resolve with fake id/path is accepted', () => {
      cy.request({
        method: 'POST',
        url: '/api/resolve',
        qs: { id: 'fake-id', path: 'pages/foobar.html' },
        failOnStatusCode: false
      }).then(res => {
        cy.wrap(res.status).should('eq', 200)
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

  // Regression test for collection path resolution during app updates
  describe('generator updates [side-effects]', () => {
    let appId

    after(() => {
      if (appId) {
        const appUri = `https://e-editiones.org/apps/${appId}`
        const repoXQuery = `repo:undeploy('${appUri}'), repo:remove('${appUri}')`

        cy.request({
          method: 'GET',
          url: 'http://localhost:8080/exist/rest/db',
          auth: { user: 'admin', pass: '' },
          qs: {
            _query: repoXQuery,
            _wrap: 'no'
          },
          failOnStatusCode: false
        }).then(({ status, body }) => {
          // Cleanup may fail if app wasn't deployed, which is fine
          if (status === 200) {
            cy.wrap(body).should('match', /result="ok"/)
          }
        })
      }
    })

    it('POST /api/generator can update app with CI profile without collection errors', () => {
      appId = 'test-ci-update-' + Date.now()
      const config = {
        config: {
          id: `https://e-editiones.org/apps/${appId}`,
          label: 'CI Update Test',
          type: 'app',
          base: 'base10',
          feature: ['ci'],
          ci: {
            provider: 'github'
          },
          docker: {
            ports: { http: 8080 }
          }
        },
        resolve: []
      }

      // First generation - creates the app with CI profile
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'all' },
        headers: { 'content-type': 'application/json' },
        body: config
      }).then(firstRes => {
        cy.wrap(firstRes).its('status').should('eq', 200)

        // Second generation - update the same app (this is where the bug occurred)
        // Using 'quick' triggers the _update path which checks last-modified timestamps
        cy.request({
          method: 'POST',
          url: '/api/generator',
          qs: { overwrite: 'quick' },
          headers: { 'content-type': 'application/json' },
          body: config,
          failOnStatusCode: false
        }).then(secondRes => {
          // Should succeed without "Collection .github/workflows not found" error
          cy.wrap(secondRes).its('status').should('eq', 200)

          // Verify no error messages in response
          const responseStr = JSON.stringify(secondRes.body)
          cy.wrap(responseStr).should('not.include', 'Collection .github/workflows not found')
          cy.wrap(responseStr).should('not.include', 'XMLDBException')
          cy.wrap(responseStr).should('not.include', 'Could not locate collection')

          // Verify response structure indicates success
          cy.wrap(secondRes.body).should('be.an', 'object')
          if (secondRes.body.messages) {
            // Check that no error messages are present
            const messages = Array.isArray(secondRes.body.messages) 
              ? secondRes.body.messages 
              : []
            const errorMessages = messages.filter(msg => 
              msg && typeof msg === 'object' && 
              (msg.type === 'error' || msg.message?.includes('Collection') || msg.message?.includes('not found'))
            )
            cy.wrap(errorMessages.length).should('eq', 0, 'No error messages should be present')
          }
        })
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
  })
})