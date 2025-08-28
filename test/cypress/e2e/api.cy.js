describe('api docs', () => {
  beforeEach(() => {
    cy.loginApi()
    cy.visit('api.html')
  })

  it('should show title header', () => {
    cy.get('.title')
      .contains('jinks API')
  })
})