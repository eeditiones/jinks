describe('Health checks', () => {
  it('serves the app root', () => {
    cy.request('/').its('status').should('eq', 200)
  })

  it('serves index.html explicitly', () => {
    cy.request('/index.html').its('status').should('eq', 200)
  })

  it('exposes api description', () => {
    cy.request('modules/api.json').then(res => {
      cy.wrap(res).its('status').should('eq', 200)
      cy.wrap(res).its('body').should('have.property', 'openapi')
      cy.wrap(res).its('body').should('have.property', 'info')
    })
  })

  it('exposes main json schema', () => {
    cy.request('schema/jinks.json').then(res => {
      cy.wrap(res).its('status').should('eq', 200)
      cy.wrap(res).its('body').should('have.property', '$schema')
      cy.wrap(res).its('body').should('have.property', 'properties')
    })
  })
})


