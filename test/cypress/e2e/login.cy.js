describe('login page', () => {
  beforeEach(() => {
    cy.visit('/')
  })

  it('should succeed with keyboard', () => {
    cy.get('#loginDialog')
      .should('be.visible')
      .find('#input-1')
      .type('tei')
    cy.press(Cypress.Keyboard.Keys.TAB)
    cy.get('#input-2')
      .type('simple{enter}')
    cy.get('#login')
      .contains('Logged in as tei')  
  })

  it('should fail without credentials', () => {
    cy.get('#loginDialog')
      .should('be.visible')
      .find('#input-1')
      .type('tei')
    cy.get('paper-button')
      .contains('Login')
      .click()
    cy.get('#login')
      .should('not.contain', 'Logged in as tei')
    cy.get('#message')
      .contains('Wrong password')
  })
})