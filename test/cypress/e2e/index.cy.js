describe('index page', () => {
  beforeEach(() => {
    cy.loginApi()
    cy.visit('/')
  })

  describe('nav bar', () => {
    it('should be visible', () => {
      cy.get('.container-fluid > nav')
        .should('be.visible')
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
    it('should 4 sections and 2 headers', () => {
      cy.get('h3')
        .should('have.length', 2)
        .contains('Configuration')
      cy.get('#config > section')
        .should('have.length', 4)
    })

    // TP Base + Dark mode + docker
    // see #106
    it.skip('should simulate creating a custom app with selected features (dry mode)', () => {
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
      cy.get('.error')
        .should('not.exist')
    })

    it('should create a custom app with selected features (forced overwrite)', () => {
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
      cy.contains('Package is deployed. Visit it here', { timeout: 50000 })
    })



    it('the profiles section has 3 subsections with sensible defaults', () => {
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

    })
  })

})