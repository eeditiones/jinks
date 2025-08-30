describe('Profile Documentation', () => {
  beforeEach(() => {
    cy.loginApi()
  })

  it('should show article with titles and mardown', () => {
    cy.visit('/profile/theme-base10')
    cy.get('h1')
      .should('be.visible')
      .contains('Theme')
    cy.get('article')
      .should('be.visible')
      .and('have.length.gte', 1)
    cy.get('pb-markdown')
      .should('be.visible')
    cy.get('h3')
      .should('be.visible')
      .and('have.length.gte', 2)
  })

  it('should expand editor for config.json', () => {
    cy.visit('/profile/base10')

    cy.get('h1')
      .find('.monaco-editor')
      .should('not.exist')
    cy.get('h1 > .source')
      .should('be.visible')
      .click()
    cy.get('h1')
      .find('.monaco-editor')
      .should('be.visible')
  })
})