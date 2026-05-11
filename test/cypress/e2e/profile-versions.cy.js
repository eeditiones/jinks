describe('profile version tracking', () => {
  Cypress.on('uncaught:exception', (err, runnable) => {
    return false
  })

  beforeEach(() => {
    cy.loginApi()
    cy.visit('/')
  })

  describe('breaking changes detection [side-effects]', () => {
    after(() => {
      const appUri1 = 'https://e-editiones.org/apps/e2eversiontest1'
      cy.request({
        method: 'GET',
        url: `http://localhost:8080/exist/rest/db`,
        auth: { user: 'admin', pass: '' },
        qs: { _query: `repo:undeploy('${appUri1}'), repo:remove('${appUri1}')`, _wrap: 'no' },
        failOnStatusCode: false
      })
    })

    it('should warn about breaking changes and allow confirmation', () => {
      const testAppAbbrev = 'e2eversiontest1'

      cy.intercept({ method: 'POST', pathname: '**/jinks/api/generator' }).as('generate')

      // Step 1: Create app with upload profile (v1.0.0)
      cy.get('[name="abbrev"]').type(`${testAppAbbrev}{enter}`)
      cy.get('[name="label"]').type('Version Test App')
      cy.get('nav.tabs > ul > li > a[href="#profiles"]').click()
      cy.get('section[data-tab="profiles"]').should('be.visible')
      cy.get('[type="checkbox"][name="feature"]').check('upload')
      cy.get('nav.tabs > ul > li > a[href="#config"]').click()
      cy.get('footer .apply-config').click()
      cy.wait('@generate', { responseTimeout: 60000 })
      cy.contains('Package is deployed. Visit it here', { timeout: 30000 })

      // Verify jinks version is recorded in .jinks-versions.json
      cy.request({
        method: 'GET',
        url: `http://localhost:8080/exist/rest/db`,
        auth: { user: 'admin', pass: '' },
        qs: {
          _query: `json-doc('/db/apps/${testAppAbbrev}/.jinks-versions.json')?jinks`,
          _wrap: 'no'
        }
      }).then((response) => {
        expect(response.body).to.match(/^\d+\.\d+\.\d+$/)
      })

      // Step 2: Downgrade recorded profile version to simulate older app
      cy.request({
        method: 'GET',
        url: `http://localhost:8080/exist/rest/db`,
        auth: { user: 'admin', pass: '' },
        qs: {
          _query: `let $c := json-doc('/db/apps/${testAppAbbrev}/.jinks-versions.json') return xmldb:store('/db/apps/${testAppAbbrev}', '.jinks-versions.json', serialize(map:merge(($c, map { 'profiles': map { 'upload': '0.0.1' } })), map { 'method': 'json' }))`,
          _wrap: 'no'
        }
      })

      // Step 3: Update should show warning (0.0.1 -> x.x.x)
      cy.intercept({ method: 'POST', pathname: '**/jinks/api/generator' }).as('update')
      cy.reload()
      cy.get('.installed li').contains('Version Test App').click()
      cy.get('footer .apply-config').click()
      cy.wait('@update')
      cy.get('#version-check-dialog', { timeout: 10000 }).should('be.visible')
      cy.get('#breaking-changes').should('contain', 'upload')
      cy.get('#breaking-changes').should('contain', '0.0.1')

      // Step 4: Confirm update
      cy.intercept({ method: 'POST', pathname: '**/jinks/api/generator' }).as('confirmUpdate')
      cy.get('#confirm-update').click()
      cy.wait('@confirmUpdate', { responseTimeout: 60000 })
      cy.contains('Update completed.', { timeout: 30000 })

      // Step 5: Second update should not warn
      cy.intercept({ method: 'POST', pathname: '**/jinks/api/generator' }).as('secondUpdate')
      cy.reload()
      cy.get('.installed li').contains('Version Test App').click()
      cy.get('footer .apply-config').click()
      cy.wait('@secondUpdate', { responseTimeout: 60000 })
    //   cy.get('#version-check-dialog').should('not.exist')
      cy.contains('Update completed.', { timeout: 30000 })
    })
  })
})
