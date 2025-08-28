describe('index page', () => {
  beforeEach(() => {
    cy.loginApi()
    cy.visit('/')
  })

  it('should show headers', () => {
    cy.get('h3')
      .should('have.length', 2)
      .contains('Configuration')
  })

  it('user should be logged in', () => {
    cy.get('#login')
      .should('be.visible')
  })
})