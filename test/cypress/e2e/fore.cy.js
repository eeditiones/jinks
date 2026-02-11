/**
 * Fore library: version 2.9.0, consistent config (script.fore).
 *
 * On index.fx.html, Fore (fx-fore) drives the UI: it loads /api/configurations into
 * an instance, binds fx-repeat to render the profile list, and on profile click loads
 * /api/configuration and shows the form; Dry run / Run submit to /api/generator.
 * App generation itself is covered by index.cy.js (main index.html form); here we
 * assert that Fore on index.fx.html actually works (initializes and binds data).
 */
describe('fore', () => {
  beforeEach(() => {
    cy.loginApi()
  })

  describe('manager UI (index.fx.html)', () => {
    it('fore initializes and binds profile list from API', () => {
      cy.visit('/index.fx.html')
      cy.get('fx-fore', { timeout: 5000 }).should('exist')
      // Fore loads i-profiles from /api/configurations and fx-repeat renders one .widget per profile
      cy.get('nav a.widget', { timeout: 10000 })
        .should('have.length.gte', 1)
        .first()
        .find('label')
        .should('exist')
      // Dry run / Run buttons show the form is wired
      cy.get('main fx-trigger button').contains('Dry run').should('be.visible')
      cy.get('main fx-trigger button').contains('Run').should('be.visible')
    })
  })

  describe('profile config', () => {
    // Expected fore version: same as jinks root package.json (strip ^/~)
    const expectedForeFromPackage = () =>
      cy.readFile('package.json').then(pkg => {
        const raw = (pkg.dependencies && pkg.dependencies['@jinntec/fore']) ||
          (pkg.devDependencies && pkg.devDependencies['@jinntec/fore'])
        return raw ? raw.replace(/^[\^~]/, '') : null
      })

    it('profiles that use fore have script.fore matching jinks package.json', () => {
      expectedForeFromPackage().then(expected => {
        expect(expected, 'fore version from package.json').to.match(/^\d+\.\d+\.\d+$/)
        cy.request('/api/configurations').then(res => {
          cy.wrap(res).its('status').should('eq', 200)
          const profilesWithFore = (res.body || []).filter(
            p => p.config?.script?.fore != null
          )
          expect(profilesWithFore.length).to.be.gte(1)
          profilesWithFore.forEach(p => {
            expect(p.config.script.fore).to.eq(
              expected,
              `profile ${p.profile} script.fore should match package.json "${expected}"`
            )
          })
        })
      })
    })
  })
})
