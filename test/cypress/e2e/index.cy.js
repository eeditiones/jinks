describe('index page', () => {
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
    it('should have 4 sections with 2 headers', () => {
      cy.get('h3')
        .should('have.length', 2)
        .contains('Configuration')
      cy.get('#config > section')
        .should('have.length', 4)
    })

    it('the profiles section should have 3 subsections selected defaults', () => {
      cy.get('#profiles > fieldset')
        .should('have.length.gte', 3)
      cy.get('#profiles')
        .find('[name="base"]')
        .should('exist')
      cy.get('#profiles')
        .find('[name="feature"]')
        .should('exist')
      cy.get('#profiles')
        .find('[name="theme"]')
        .should('exist')
      cy.get('[type="radio"]')
        .should('have.length.gte', 2)
      cy.get('[type="checkbox"]')
        .should('have.length.gte', 15)
      cy.get(':checked')
        .should('have.length.gte', 2)
      cy.get('.error')
        .should('not.be.visible')
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
      cy.get('[type="checkbox"]')
        .check('docker')
      cy.get('#appConfig')
        .contains('docker')
      cy.get('[name="overwrite"]')
        .select('all')
      cy.get('#apply-config')
        .click()
      cy.wait('@e2eGenerate')
      cy.wait('@e2eDeploy', { responseTimeout: 40000 })
      cy.contains('Package is deployed. Visit it here', { timeout: 10000 })
      cy.get('.error')
        .should('not.be.visible')
    })
  })

})