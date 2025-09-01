describe('Templating Tester', () => {
  beforeEach(() => {
    cy.loginApi()
    cy.visit('templating.html')
  })

  it('should show editors and titles and cheatsheet', () => {
    cy.get('h1')
      .contains('Template')
    cy.get('#template')
      .should('be.visible')
    cy.get('#parameters')
      .should('be.visible')
    cy.get('details')
      .should('be.visible')
    cy.get('[data-cy="cheatsheet-link"]')
      .click()
    cy.get('#cheatsheet')
      .should('be.visible')
      .find('tbody')
      .contains('[%')
  })

  it('should allow interactive testing', () => {
    cy.intercept({
      'method': 'POST',
      'pathname': '**/jinks/api/templates',
    })
      .as('templating')

    cy.get('#examples')
      .should('be.visible')
      .select(1)
    cy.get('#template')
      .contains('[%')
    cy.get('#eval')
      .click()
    cy.wait('@templating')
    cy.get('errorMsg')
      .should('not.exist')
    cy.get('.output')
      .should('be.visible')
      .and('have.length.gte', 3)
  })
})