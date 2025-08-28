describe('Templating Tester', () => {
  beforeEach(() => {
    cy.loginApi()
    cy.visit('templating.html')
  })

  it('should show title header', () => {
    cy.get('h1')
      .contains('Template')
  })
})