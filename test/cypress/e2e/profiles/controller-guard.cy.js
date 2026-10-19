/// <reference types="cypress" />

// base10's controller.xql, with and without the app's guard (config.json, controller.guard)
describe('the controller guard', () => {
  let template

  before(() => {
    cy.readFile('profiles/base10/controller.tpl.xql').then((t) => { template = t })
  })
  beforeEach(() => {
    cy.loginApi()
  })

  const expand = (params) => cy.request({
    method: 'POST',
    url: '/api/templates',
    headers: { 'content-type': 'application/json' },
    body: { template, params: { defaults: { 'data-static': 'static' }, ...params }, mode: 'text' }
  }).then((res) => {
    expect(res.status).to.eq(200)
    return res.body.result
  })

  it('is left out when none is configured', () => {
    expand({}).then((xql) => {
      expect(xql).not.to.contain('guard')
      expect(xql).to.match(/^if \(\$exist:path eq ''\) then/m)
    })
  })

  it('imports the module and asks it first, with the request', () => {
    expand({ controller: { guard: { namespace: 'http://example.org/guard', at: 'modules/guard.xqm' } } }).then((xql) => {
      expect(xql).to.contain('import module namespace guard="http://example.org/guard" at "modules/guard.xqm";')
      // the import comes before the first expression, the guard before the first route
      expect(xql.indexOf('import module namespace guard')).to.be.lessThan(xql.indexOf('declare variable $landingPage'))
      const call = xql.indexOf('guard:dispatch(map {')
      expect(call).to.be.greaterThan(0)
      expect(call).to.be.lessThan(xql.indexOf("if ($exist:path eq '') then"))
      for (const key of ['path', 'resource', 'controller', 'prefix', 'root']) {
        expect(xql).to.contain(`"${key}": $exist:${key}`)
      }
      expect(xql).to.match(/if \(exists\(\$guarded\)\) then\s+\$guarded\s+else\s+if \(\$exist:path eq ''\) then/)
    })
  })
})
