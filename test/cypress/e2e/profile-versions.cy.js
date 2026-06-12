describe('profile version tracking', () => {
  Cypress.on('uncaught:exception', () => false)

  const testAppAbbrev = 'e2eversiontest1'
  const appUri = `https://e-editiones.org/apps/${testAppAbbrev}`

  const generatorBody = {
    config: {
      id: appUri,
      label: 'Version Test App',
      extends: ['base10', 'upload'],
      pkg: { abbrev: testAppAbbrev }
    },
    resolve: []
  }

  function existQuery(query) {
    return cy.request({
      method: 'GET',
      url: 'http://localhost:8080/exist/rest/db',
      auth: { user: 'admin', pass: '' },
      qs: { _query: query, _wrap: 'no' }
    })
  }

  function cleanupApp() {
    return cy.request({
      method: 'GET',
      url: 'http://localhost:8080/exist/rest/db',
      auth: { user: 'admin', pass: '' },
      qs: { _query: `repo:undeploy('${appUri}'), repo:remove('${appUri}')`, _wrap: 'no' },
      failOnStatusCode: false
    })
  }

  beforeEach(() => {
    cy.loginApi()
  })

  describe('breaking changes detection [side-effects]', () => {
    before(() => {
      cy.loginApi()
      cleanupApp()
    })

    after(() => {
      cy.loginApi()
      cleanupApp()
    })

    it('should warn about breaking changes and allow confirmation', () => {
      // Step 1: Create and deploy app via API
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'all' },
        headers: { 'content-type': 'application/json' },
        body: generatorBody
      }).then((res) => {
        expect(res.status).to.eq(200)
        expect(res.body.nextStep.action).to.eq('DEPLOY')
      })

      cy.request({
        method: 'POST',
        url: `/api/generator/${testAppAbbrev}/deploy`
      }).its('status').should('eq', 200)

      // Verify jinks version is recorded in .jinks-versions.json
      existQuery(`json-doc('/db/apps/${testAppAbbrev}/.jinks-versions.json')?jinks`).then((response) => {
        expect(response.body).to.match(/^\d+\.\d+\.\d+$/)
      })

      // Step 2: Downgrade recorded profile version to simulate older app
      existQuery(
        `let $c := json-doc('/db/apps/${testAppAbbrev}/.jinks-versions.json') ` +
        `return xmldb:store('/db/apps/${testAppAbbrev}', '.jinks-versions.json', ` +
        `serialize(map:merge(($c, map { 'profiles': map { 'upload': '0.0.1' } })), map { 'method': 'json' }))`
      )

      // Step 3: UI update should show breaking-changes dialog (0.0.1 → 1.0.0)
      cy.request('/api/configurations').then(({ body }) => {
        const app = body.find(
          (entry) => entry.type === 'installed' && entry.config?.pkg?.abbrev === testAppAbbrev
        )
        expect(app, 'deployed app in configurations').to.exist
        expect(app.title).to.eq('Version Test App')
      })

      cy.intercept('GET', '**/api/configurations').as('configurations')
      cy.intercept({ method: 'POST', pathname: '**/api/generator' }).as('update')
      cy.visit('/')
      cy.wait('@configurations')
      cy.get('.installed li').contains('Version Test App', { timeout: 15000 }).click()
      cy.get('footer .apply-config').click()
      cy.wait('@update', { responseTimeout: 60000 })
      cy.get('#version-check-dialog[open]', { timeout: 15000 }).should('exist')
      cy.get('#breaking-changes').should('contain', 'upload')
      cy.get('#breaking-changes').should('contain', '0.0.1')

      // Step 4: Confirm update via UI
      cy.intercept({ method: 'POST', pathname: '**/api/generator' }).as('confirmUpdate')
      cy.get('#confirm-update').click()
      cy.wait('@confirmUpdate', { responseTimeout: 60000 }).then(({ response }) => {
        expect(response.statusCode).to.eq(200)
        // version-check still reports detected breaking changes; confirm only unblocks the update
        expect(response.body['version-check']['has-breaking-changes']).to.be.true
        expect(response.body['version-check']['breaking-profiles']).to.have.property('upload')
        expect(response.body.nextStep.action).to.not.eq('CONFIRM')
      })
      cy.get('#version-check-dialog[open]').should('not.exist')
      cy.get('#output-dialog[open]', { timeout: 15000 }).should('exist')
      cy.get('#output .error').should('be.empty')

      // Step 5: Second update via API should not warn
      cy.request({
        method: 'POST',
        url: '/api/generator',
        qs: { overwrite: 'quick' },
        headers: { 'content-type': 'application/json' },
        body: generatorBody
      }).then((res) => {
        expect(res.status).to.eq(200)
        expect(res.body['version-check']['has-breaking-changes']).to.be.false
        expect(res.body.nextStep.action).to.not.eq('CONFIRM')
      })
    })
  })
})
