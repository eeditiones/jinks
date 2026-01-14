describe('index page', () => {
  // Ignore specific uncaught exceptions that are not critical
  Cypress.on('uncaught:exception', (err, runnable) => {
    // Ignore only "NetworkError when attempting to fetch resource"
    if (err.message.includes('NetworkError when attempting to fetch resource')) {
      // returning false here prevents Cypress from failing the test
      return false
    }
    // don't prevent test failure on other errors
    return true
  })

  beforeEach(() => {
    cy.loginApi()
    cy.visit('/')
  })

  describe('nav bar', () => {
    it('should be visible', () => {
      cy.get('nav')
        .should('be.visible')
        .and('have.length.gte', 2)
    })

    it('user should be logged in', () => {
      cy.get('pb-login')
        .should('have.attr', 'logged-in')
    })

    it('mode button should toggle between light and dark', () => {
      cy.get('body')
        .invoke('attr', 'data-theme')
        .should('be.oneOf', [undefined, null, '', 'dark', 'light'])
        .then(initialTheme => {
          cy.get('#colorMode')
            .should('be.visible')
            .click()
          cy.get('body')
            .invoke('attr', 'data-theme')
            .should('be.oneOf', ['dark', 'light'])
          cy.get('#colorMode')
            .should('be.visible')
            .click()
          cy.get('body')
            .invoke('attr', 'data-theme')
            .should(newTheme => {
              expect(newTheme).not.to.eq(initialTheme)
            })
        })
    })

    it('menus should allow click navigation', () => {
      cy.get('nav > ul')
        .should('have.length.gte', 3)
      cy.get('.dropdown > summary')
        .contains('Tools')
        .click()
      cy.get('.dropdown > ul')
        .contains('Templating Tester')
        .click()
      cy.url()
        .should('include', '/templating.html')
      cy.get('.dropdown > summary')
        .click()
      cy.get('.dropdown > ul > :nth-child(2) > a')
        .contains('API Documentation')
        .invoke('attr', 'href')
        .should('include', '/api.html')
    })
  })

  describe('content area', () => {
    it('should have the config tab selected by default', () => {
      cy.get('nav.tabs > ul > li > a')
        .contains('Application Configuration')
        .should('have.class', 'active')
      cy.get('section[data-tab="config"]')
        .should('be.visible')
    })

    it('should have abbrev filled in', () => {
      cy.get('[name="abbrev"]')
        .type('e2edry{enter}')
    })

    it('should have the profiles tab', () => {
      cy.get('nav.tabs > ul > li > a[href="#profiles"]')
        .should('not.have.class', 'active')
        .click()
      cy.get('section[data-tab="profiles"]')
        .should('be.visible')
      cy.get('#profiles')
        .find('[name="base"]')
        .should('exist')
      cy.get('#profiles')
        .find('[name="feature"]')
        .should('exist')
    })

    it('should have the theming tab', () => {
      cy.get('nav.tabs > ul > li > a[href="#theming"]')
        .should('not.have.class', 'active')
        .click()
      cy.get('section[data-tab="theming"]')
        .should('be.visible')
    })
      
    it('theming tab should have a theme selected by default', () => {
      cy.get('nav.tabs > ul > li > a[href="#theming"]')
      .click()
      cy.get('section[data-tab="theming"]')
        .should('be.visible')
        .find('[name="theme"]:checked')
        .should('exist')
      cy.get('.color-scheme-picker')
        .find('[name="color-palette"][value="neutral"]')
        .should('exist')
    })

    it('theming tab should have color palettes loaded', () => {
      cy.get('nav.tabs > ul > li > a[href="#theming"]')
        .click()
      cy.get('.color-scheme-picker')
        .find('[name="color-palette"][value="neutral"]')
        .should('exist')
    })

    it('the custom ODD picker should modify config', () => {
      cy.get('[name="custom-odd"]')
        .type('e2etest.odd')
      cy.get('#add-odd')
        .click()
      cy.get('#appConfig')
        .contains('"odd": "e2etest.odd"')
    })

    it.skip('the toolbar should ...', () => {
      cy.get('.toolbar')
        .should('not.be.visible')
      // TODO(DP)
    })
  })

  // Missing test areas
  // generation with overwrite: force
  // Actions panel:
  //   - fix-odds
  //   - reindex
  // toolbar with generated app link icons (only visible with pre-existing apps)
  // info pop ups and tooltips
  // negative paths throughout the spec
  // modify an existing app


  describe('deployments [side-effects]', () => {
    after(() => {
      const appUri = 'https://e-editiones.org/apps/e2etest'
      const repoXQuery = `repo:undeploy('${appUri}'), repo:remove('${appUri}')`

      cy.request({
        method: 'GET',
        url: `http://localhost:8080/exist/rest/db`,
        auth: { user: 'admin', pass: '' },
        qs: {
          _query: repoXQuery,
          _wrap: 'no',
        }
      }).then(({ status, body }) => {
        cy.wrap(status).should('eq', 200)
        cy.wrap(body).should('match', /result="ok"/)
      })

      })

     // TP Base + Dark mode + docker
    // see #106
    it.skip('should simulate creating a custom app with selected features (dry mode)', () => {
      cy.intercept({
        'method': 'POST',
        'pathname': '**/jinks/api/generator',
        'query': {
          overwrite: 'quick',
          dry: 'true',
        }
      })
        .as('dryTest')

      cy.get('[name="abbrev"]')
        .type('e2edry{enter}')
      cy.get('[name="label"]')
        .type(' application')
      cy.get('[name="id"]')
      cy.contains('https://e-editiones.org/apps/e2edry')
      cy.get('[type="checkbox"]')
        .check('docker')
      cy.get('#appConfig')
        .contains('docker')
      cy.get('#dry-run')
        .click()
      cy.wait('@dryTest')
      cy.get('.error')
        .contains('not.be.visible')
    })

    it('should force create a custom app with selected features [side-effects]', () => {
      cy.intercept({
        'method': 'POST',
        'pathname': '**/jinks/api/generator',
        'query': {
          overwrite: 'all',
        }
      })
        .as('e2eGenerate')

      cy.intercept({
        'method': 'POST',
        'pathname': '**/api/generator/e2etest/deploy',
      })
        .as('e2eDeploy')

      cy.get('[name="abbrev"]')
        .type('e2etest{enter}')
      cy.get('[name="label"]')
        .type(' application')
      cy.get('[name="id"]')
      cy.contains('https://e-editiones.org/apps/e2etest')

      cy.get('nav.tabs > ul > li > a[href="#profiles"]')
        .should('not.have.class', 'active')
        .click()
      cy.get('section[data-tab="profiles"]')
        .should('be.visible')

      cy.get('[type="checkbox"]')
        .check('ci')
      cy.get('#appConfig')
        .contains('docker')
      
      cy.get('nav.tabs > ul > li > a[href="#config"]')
        .should('not.have.class', 'active')
        .click()
      cy.get('section[data-tab="config"]')
        .should('be.visible')

      cy.get('[name="overwrite"]')
        .select('all')
      cy.get('footer .apply-config')
        .click()
      cy.wait('@e2eGenerate')
      cy.wait('@e2eDeploy', { responseTimeout: 40000 })
      // Assert first we have no errors. Otherwise the assert after it times out
      cy.get('.error')
        .should('be.empty')
      cy.contains('Package is deployed. Visit it here', { timeout: 10000 })

      cy.get('#open-action').then(link => cy.request(link.prop('href')))
    })
  })

})
