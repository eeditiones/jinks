// Contract checks derived from OpenAPI specs (modules/api.json, modules/deploy-api.json)

const apis = [
  { name: 'core', path: 'modules/api.json' },
  { name: 'deploy', path: 'modules/deploy-api.json' }
]

describe('OpenAPI contract', () => {
  beforeEach(() => {
    cy.loginApi()
  })

  apis.forEach(api => {
    describe(api.name, () => {
      it(`spec ${api.path} is served and has required fields`, () => {
        cy.request(api.path).then(res => {
          cy.wrap(res).its('status').should('eq', 200)
          cy.wrap(res.headers).its('content-type').should('include', 'application/json')
          cy.wrap(res.body).its('openapi').should('eq', '3.0.3')
          cy.wrap(res.body).its('info').its('title').should('include', 'jinks API')
        })
      })
    })
  })
})


