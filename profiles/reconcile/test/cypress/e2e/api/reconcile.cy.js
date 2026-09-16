// Reconciliation API tests (both 0.2 and 1.0-draft) for the `reconcile` profile.
// Uses base10's cy.api() (CORS-clean localhost Origin) and cy.validateSchema()
// (cypress-ajv-schema-validator), and the vendored + bundled reconciliation JSON
// Schemas under test/cypress/fixtures/schemas/{0.2,1.0}.

describe('reconciliation API (1.0-draft, default manifest)', () => {
  let manifestSchema
  let resultSchema

  before(() => {
    cy.fixture('schemas/1.0/manifest.json').then((s) => { manifestSchema = s })
    cy.fixture('schemas/1.0/reconciliation-result-batch.json').then((s) => { resultSchema = s })
  })

  it('GET (no params) returns a schema-valid 1.0-draft manifest', () => {
    cy.api({ url: '/api/reconcile' })
      .validateSchema(manifestSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.versions).to.include('1.0-draft')
        expect(body.view.url).to.match(/\{.*id.*\}/)
      })
  })

  it('POST /api/reconcile/match with a 1.0-draft queries array returns a schema-valid result batch', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }] },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.results).to.be.an('array').with.length(1)
        expect(body.results[0].candidates).to.be.an('array').that.is.not.empty
        expect(body.results[0].candidates[0].name).to.include('Goethe')
        const scores = body.results[0].candidates.map((c) => c.score)
        expect(scores).to.deep.equal([...scores].sort((a, b) => b - a))
      })
  })

  it('POST /api/reconcile (root alias) accepts the same 1.0-draft payload', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }] },
    })
      .validateSchema(resultSchema)
      .its('body.results.0.candidates.0.id')
      .should('be.a', 'string')
  })
})

describe('matching on non-name query conditions (property/id, both spec versions)', () => {
  let resultSchema

  before(() => {
    cy.fixture('schemas/1.0/reconciliation-result-batch.json').then((s) => { resultSchema = s })
  })

  it('a required property condition that fails excludes a same-named candidate', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: {
        queries: [{
          type: 'person',
          conditions: [
            { matchType: 'name', propertyValue: 'Goethe' },
            { matchType: 'property', propertyId: 'gender', propertyValue: 'female', required: true, matchQualifier: 'ExactMatch' },
          ],
        }],
      },
    })
      .validateSchema(resultSchema)
      .its('body.results.0.candidates')
      .should('deep.equal', [])
  })

  it('...but the same required condition, when it actually matches, keeps and boosts the candidate', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: {
        queries: [{
          type: 'person',
          conditions: [
            { matchType: 'name', propertyValue: 'Goethe' },
            { matchType: 'property', propertyId: 'gender', propertyValue: 'male', required: true, matchQualifier: 'ExactMatch' },
          ],
        }],
      },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const candidate = body.results[0].candidates[0]
        expect(candidate.id).to.eq('kbga-actors-136')
        // ~41.38 (name alone, asserted earlier in this suite) + the flat 20-point
        // boost for the matched required property condition.
        expect(candidate.score).to.be.greaterThan(41.4)
      })
  })

  it('matchType "id" resolves a known entity directly, at score 100', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ conditions: [{ matchType: 'id', propertyValue: 'kbga-actors-136' }] }] },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const candidate = body.results[0].candidates[0]
        expect(candidate.id).to.eq('kbga-actors-136')
        expect(candidate.score).to.eq(100)
        expect(candidate.match).to.eq(true)
      })
  })

  it('a property-only query with no name condition at all finds an entity purely by its "gnd" property (mirrors the spec\'s own "no query string" example)', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: {
        queries: [{
          type: 'person',
          conditions: [
            { matchType: 'property', propertyId: 'gnd', propertyValue: 'https://d-nb.info/gnd/119442086', matchQualifier: 'ExactMatch' },
          ],
        }],
      },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const candidates = body.results[0].candidates
        expect(candidates).to.have.length(1)
        expect(candidates[0].id).to.eq('gnd-119442086')
        expect(candidates[0].score).to.be.greaterThan(0)
      })
  })

  it('the same property-condition matching works via 0.2\'s flat "properties" array, not just 1.0-draft "conditions"', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { q0: { properties: [{ pid: 'gnd', v: 'https://d-nb.info/gnd/119442086' }] } },
    }).then(({ status, body }) => {
      expect(status).to.eq(200)
      expect(body.q0.result).to.have.length(1)
      expect(body.q0.result[0].id).to.eq('gnd-119442086')
    })
  })
})

describe('reconciliation API (0.2, ?version=0.2 manifest)', () => {
  let manifestSchema
  let resultSchema

  before(() => {
    cy.fixture('schemas/0.2/manifest.json').then((s) => { manifestSchema = s })
    cy.fixture('schemas/0.2/reconciliation-result-batch.json').then((s) => { resultSchema = s })
  })

  it('GET ?version=0.2 returns a schema-valid 0.2 manifest', () => {
    cy.api({ url: '/api/reconcile', qs: { version: '0.2' } })
      .validateSchema(manifestSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.versions).to.include('0.2')
        expect(body.identifierSpace).to.be.a('string')
        expect(body.schemaSpace).to.be.a('string')
      })
  })

  it('POST a 0.2 query-id-keyed batch returns a schema-valid result batch', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { q0: { query: 'Goethe' } },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body).to.have.property('q0')
        expect(body.q0.result).to.be.an('array').that.is.not.empty
        const scores = body.q0.result.map((c) => c.score)
        expect(scores).to.deep.equal([...scores].sort((a, b) => b - a))
      })
  })

  it('POST a form-urlencoded "queries=<json>" batch (classic 0.2 wire format) also works', () => {
    // The local 0.2 test bench posts application/x-www-form-urlencoded with a
    // "queries" form field, not raw JSON — see reconc:reconcile's form-data branch.
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      form: true,
      body: { queries: JSON.stringify({ q0: { query: 'Goethe' } }) },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.q0.result).to.be.an('array').that.is.not.empty
      })
  })
})

describe('fuzzy / typo-tolerant matching', () => {
  let resultSchema

  before(() => {
    cy.fixture('schemas/1.0/reconciliation-result-batch.json').then((s) => { resultSchema = s })
  })

  it('a misspelled single-token query still finds the right person, with a nonzero score', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Goehte' }] }] },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const candidates = body.results[0].candidates
        expect(candidates).to.be.an('array').that.is.not.empty
        expect(candidates[0].id).to.eq('kbga-actors-136')
        expect(candidates[0].score).to.be.greaterThan(0)
      })
  })

  it('a batched query returns the same candidates as the same query sent alone (pooling does not change results)', () => {
    const query = { type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }
    cy.api({
      method: 'POST',
      url: '/api/reconcile/match',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [query] },
    }).then(({ body: alone }) => {
      cy.api({
        method: 'POST',
        url: '/api/reconcile/match',
        headers: { 'Content-Type': 'application/json' },
        body: { queries: [query, { type: 'place', conditions: [{ matchType: 'name', propertyValue: 'Madrid' }] }] },
      }).then(({ body: batched }) => {
        expect(batched.results[0].candidates).to.deep.equal(alone.results[0].candidates)
      })
    })
  })
})

describe('suggest services (shape shared by 0.2 and 1.0-draft)', () => {
  let entitySchema
  let propertySchema
  let typeSchema

  before(() => {
    cy.fixture('schemas/1.0/suggest-entities-response.json').then((s) => { entitySchema = s })
    cy.fixture('schemas/1.0/suggest-properties-response.json').then((s) => { propertySchema = s })
    cy.fixture('schemas/1.0/suggest-types-response.json').then((s) => { typeSchema = s })
  })

  it('GET /suggest/entity?prefix=Goethe finds the Goethe person entity', () => {
    cy.api({ url: '/api/reconcile/suggest/entity', qs: { prefix: 'Goethe' } })
      .validateSchema(entitySchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.result.map((r) => r.id)).to.include('kbga-actors-136')
      })
  })

  it('GET /suggest/property?prefix=gen finds the "gender" property', () => {
    cy.api({ url: '/api/reconcile/suggest/property', qs: { prefix: 'gen' } })
      .validateSchema(propertySchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.result.map((r) => r.id)).to.include('gender')
      })
  })

  it('GET /suggest/type?prefix=per finds the "person" type', () => {
    cy.api({ url: '/api/reconcile/suggest/type', qs: { prefix: 'per' } })
      .validateSchema(typeSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.result.map((r) => r.id)).to.include('person')
      })
  })
})

describe('suggest/flyout (0.2 legacy hover preview)', () => {
  it('kind=property returns an escaped <p> with the property name', () => {
    cy.api({ url: '/api/reconcile/suggest/flyout', qs: { kind: 'property', id: 'gnd' } })
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.html).to.eq('<p>GND identifier</p>')
      })
  })

  it('kind=type returns an escaped <p> with the type name', () => {
    cy.api({ url: '/api/reconcile/suggest/flyout', qs: { kind: 'type', id: 'person' } })
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.html).to.eq('<p>Person</p>')
      })
  })

  it('kind=entity returns an escaped <p> with the entity label', () => {
    cy.api({ url: '/api/reconcile/suggest/flyout', qs: { kind: 'entity', id: 'gnd-119442086' } })
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.html).to.include('Dantiscus')
      })
  })

  // Regression test for a real, live-confirmed stored-XSS: reconc:suggest-flyout builds its
  // "html" field via plain string concatenation (not a real element constructor), and its
  // entity branch interpolates reconc:label(...) - text extracted straight from document
  // content (tei:persName), which anyone with document-edit access can influence. This "html"
  // field is embedded directly into the page DOM by clients (OpenRefine's own suggest widget
  // does `.html(data.html)`; this project's own annotate-editor connector does
  // `container.innerHTML = output` on the sibling /preview route's response - see
  // ReconciliationService.info() in tei-publisher-components). Before the fix, a persName
  // containing a literal "<script>" came back completely unescaped in this response.
  describe('escapes document-sourced content (regression, XSS)', () => {
    const personDoc = '/db/apps/tp-reconc/data/registers/persons.xml'
    const targetId = 'gnd-119442086'
    const originalName = 'Dantiscus, Ioannes'
    const payloadName = 'Dantiscus, Ioannes<script>alert(document.domain)</script>'

    function setPersName(value) {
      const query = `
        declare namespace tei="http://www.tei-c.org/ns/1.0";
        let $e := doc("${personDoc}")//tei:person[@xml:id="${targetId}"]/tei:persName[1]
        return (update value $e with "${value.replace(/</g, '&lt;').replace(/>/g, '&gt;')}", "ok")
      `
      return cy.request({
        method: 'POST',
        url: 'http://localhost:8080/exist/rest/db',
        auth: { user: 'admin', password: '' },
        headers: { 'Content-Type': 'application/xml' },
        body: `<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no"><text><![CDATA[${query}]]></text></query>`,
        failOnStatusCode: false,
      })
    }

    before(() => setPersName(payloadName))
    after(() => setPersName(originalName))

    it('never reflects a raw <script> tag in the flyout html', () => {
      cy.api({ url: '/api/reconcile/suggest/flyout', qs: { kind: 'entity', id: targetId } })
        .then(({ body }) => {
          expect(body.html).to.not.include('<script>')
          expect(body.html).to.include('&lt;script&gt;')
        })
    })
  })
})

// Regression tests for a real bug: these "limit" query parameters used to be declared
// "type": "integer" in the OpenAPI spec, so roaster's own parameter-casting middleware
// (parameters.xql) called xs:integer() on the raw value with no try/catch *before* the
// handler ever ran - a non-numeric "limit" 500'd with an internal module path/line leaked
// in the response body instead of a clean fallback. Now declared "type": "string" and
// parsed leniently via reconc:safe-limit, matching how the POST body's own "limit" field
// (never roaster-typed) already worked.
describe('the "limit" query parameter degrades gracefully on every route that has one', () => {
  ['suggest/entity', 'suggest/property', 'suggest/type'].forEach((route) => {
    it(`GET /${route}?limit=abc falls back to the default instead of a 500`, () => {
      cy.api({ url: `/api/reconcile/${route}`, qs: { prefix: 'a', limit: 'abc' } })
        .then(({ status, body }) => {
          expect(status).to.eq(200)
          expect(body.result).to.be.an('array')
        })
    })
  })

  it('GET /extend/propose?limit=abc falls back to the default instead of a 500', () => {
    cy.api({ url: '/api/reconcile/extend/propose', qs: { type: 'person', limit: 'abc' } })
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.limit).to.eq(20)
        expect(body.properties.length).to.be.greaterThan(0)
      })
  })

  it('GET /extend/propose?limit=<huge> is clamped to MAX_LIMIT, not echoed verbatim', () => {
    cy.api({ url: '/api/reconcile/extend/propose', qs: { type: 'person', limit: '99999999999999999999' } })
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.limit).to.eq(1000)
      })
  })
})

describe('preview and view services', () => {
  it('GET /preview?id=... returns an HTML fragment mentioning the entity', () => {
    cy.api({ url: '/api/reconcile/preview', qs: { id: 'kbga-actors-136' } })
      .then(({ status, headers, body }) => {
        expect(status).to.eq(200)
        expect(headers['content-type']).to.include('text/html')
        expect(body).to.include('Goethe')
      })
  })

  // The register-overview ODD transform's own link to the entity's registers page
  // is relative (href="people/<id>"), which only resolves correctly if the preview
  // HTML is rendered as its own document at that exact path. It isn't: the
  // annotate-editor client fetches this HTML and injects it into an existing page's
  // DOM via innerHTML (tei-publisher-components' ReconciliationService.info()), so
  // a relative link resolves against whatever page happens to have the preview
  // open, e.g. ".../sermons/people/<id>" for a preview opened from a sermon
  // document. reconc:absolutize-links rewrites every link before it goes out.
  it('the entity link in the preview is absolute, not resolved against whatever page embeds it', () => {
    cy.api({ url: '/api/reconcile/preview', qs: { id: 'kbga-actors-136' } })
      .then(({ body }) => {
        const hrefs = [...body.matchAll(/href="([^"]+)"/g)].map((m) => m[1])
        expect(hrefs.length, 'at least one link in the preview').to.be.greaterThan(0)
        hrefs.forEach((href) => {
          expect(href, `href "${href}" should be absolute`).to.match(/^([a-z]+:|#)/i)
        })
        expect(body).to.include('/people/kbga-actors-136')
      })
  })

  it('lists every configured property with a real value for the entity, not just the register-overview transform', () => {
    cy.api({ url: '/api/reconcile/preview', qs: { id: 'kbga-actors-27' } })
      .then(({ body }) => {
        expect(body).to.include('Gender')
        expect(body).to.include('male')
        expect(body).to.include('Biographical note')
      })
  })

  it('renders a property whose value looks like an image as an <img>, not as text', () => {
    cy.api({ url: '/api/reconcile/preview', qs: { id: 'kbga-actors-27' } })
      .then(({ body }) => {
        expect(body).to.include('Portrait')
        expect(body).to.match(/<img[^>]+src="data:image\/svg\+xml;base64,/)
      })
  })

  it('GET /entity/{id} redirects to the real registers page for a person', () => {
    cy.api({ url: '/api/reconcile/entity/kbga-actors-136', followRedirect: false })
      .then(({ status, headers }) => {
        expect(status).to.eq(303)
        expect(headers.location).to.include('/people/kbga-actors-136')
      })
  })
})

describe('data extension (1.0-draft)', () => {
  let responseSchema
  let proposalSchema

  before(() => {
    cy.fixture('schemas/1.0/data-extension-response.json').then((s) => { responseSchema = s })
    cy.fixture('schemas/1.0/data-extension-property-proposal.json').then((s) => { proposalSchema = s })
  })

  it('POST /extend with a schema-valid query returns a schema-valid 1.0-draft response', () => {
    const query = { ids: ['kbga-actors-136'], properties: [{ id: 'gender' }] }
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: query,
    })
      .validateSchema(responseSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.rows).to.be.an('array').with.length(1)
        expect(body.rows[0].id).to.eq('kbga-actors-136')
        expect(body.rows[0].properties[0].values[0].str).to.eq('male')
      })
  })

  it('GET /api/reconcile?extend=... (classic convention) also returns a 1.0-draft response', () => {
    const query = { ids: ['kbga-actors-136'], properties: [{ id: 'gender' }] }
    cy.api({ url: '/api/reconcile', qs: { extend: JSON.stringify(query) } })
      .validateSchema(responseSchema)
      .its('body.rows.0.properties.0.values.0.str')
      .should('eq', 'male')
  })

  it('GET /extend/propose?type=person proposes the person property catalog', () => {
    cy.api({ url: '/api/reconcile/extend/propose', qs: { type: 'person' } })
      .validateSchema(proposalSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.properties.map((p) => p.id)).to.include('gender')
      })
  })

  it('POST /extend resolves external-identifier properties (gnd, occupation) for a GND-sourced person', () => {
    const query = { ids: ['gnd-119442086'], properties: [{ id: 'gnd' }, { id: 'occupation' }] }
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: query,
    })
      .validateSchema(responseSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const [gnd, occupation] = body.rows[0].properties
        expect(gnd.values[0].str).to.eq('https://d-nb.info/gnd/119442086')
        expect(occupation.values.map((v) => v.str)).to.include('Bischof')
      })
  })

  it('POST /extend resolves geonames/wikidata properties for a place, and a work\'s gnd property is scoped independently from a person\'s', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: { ids: ['dantiscus-0000001'], properties: [{ id: 'geonames' }, { id: 'wikidata' }] },
    })
      .validateSchema(responseSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        const [geonames, wikidata] = body.rows[0].properties
        expect(geonames.values[0].str).to.match(/^https:\/\/www\.geonames\.org\//)
        expect(wikidata.values[0].str).to.match(/^https:\/\/www\.wikidata\.org\//)
      })

    // "gnd" is defined on both "person" and "work" with different extractors (idno
    // vs @xml:id) — this must resolve against the entity's own actual type, not
    // whichever type happens to define "gnd" first (a real bug caught during
    // development: reconc:property-by-id's global-by-id lookup picked the wrong
    // type's extractor).
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: { ids: ['gnd-4211173-0'], properties: [{ id: 'gnd' }] },
    })
      .validateSchema(responseSchema)
      .its('body.rows.0.properties.0.values.0.str')
      .should('eq', 'https://d-nb.info/gnd/4211173-0')
  })
})

describe('data extension (0.2)', () => {
  let responseSchema

  before(() => {
    cy.fixture('schemas/0.2/data-extension-response.json').then((s) => { responseSchema = s })
  })

  it('POST /extend?version=0.2 returns a schema-valid 0.2 (id-keyed) response', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      qs: { version: '0.2' },
      headers: { 'Content-Type': 'application/json' },
      body: { ids: ['kbga-actors-136'], properties: [{ id: 'gender' }] },
    })
      .validateSchema(responseSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.rows['kbga-actors-136'].gender[0].str).to.eq('male')
      })
  })
})

describe('request-size caps (production hardening)', () => {
  let resultSchema
  let extendResponseSchema

  before(() => {
    cy.fixture('schemas/1.0/reconciliation-result-batch.json').then((s) => { resultSchema = s })
    cy.fixture('schemas/1.0/data-extension-response.json').then((s) => { extendResponseSchema = s })
  })

  it('POST /api/reconcile rejects a batch over MAX_BATCH_SIZE with 400 (1.0-draft shape)', () => {
    const queries = Array.from({ length: 501 }, () => ({ conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }))
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries },
      failOnStatusCode: false,
    }).its('status').should('eq', 400)
  })

  it('POST /api/reconcile rejects a batch over MAX_BATCH_SIZE with 400 (0.2 shape)', () => {
    const queries = {}
    for (let i = 0; i < 501; i++) queries['q' + i] = { query: 'Goethe' }
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries },
      failOnStatusCode: false,
    }).its('status').should('eq', 400)
  })

  it('a batch within MAX_BATCH_SIZE still succeeds', () => {
    const queries = Array.from({ length: 10 }, () => ({ conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }))
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.results).to.have.length(10)
      })
  })

  it('POST /extend rejects a request over MAX_EXTEND_IDS with 400', () => {
    const ids = Array.from({ length: 501 }, (_, i) => 'id' + i)
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: { ids, properties: [{ id: 'gender' }] },
      failOnStatusCode: false,
    }).its('status').should('eq', 400)
  })

  it('POST /extend rejects a request over MAX_EXTEND_PROPERTIES with 400', () => {
    const properties = Array.from({ length: 101 }, (_, i) => ({ id: 'p' + i }))
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: { ids: ['kbga-actors-136'], properties },
      failOnStatusCode: false,
    }).its('status').should('eq', 400)
  })

  it('a normal /extend request stays unaffected by the new caps', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile/extend',
      headers: { 'Content-Type': 'application/json' },
      body: { ids: ['kbga-actors-136'], properties: [{ id: 'gender' }] },
    })
      .validateSchema(extendResponseSchema)
      .its('status')
      .should('eq', 200)
  })

  it('an over-large "limit" is clamped rather than rejected or crashing the server', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ conditions: [{ matchType: 'name', propertyValue: 'Goethe' }], limit: 999999999 }] },
    })
      .validateSchema(resultSchema)
      .its('status')
      .should('eq', 200)
  })
})

// Regression coverage for a real OpenRefine run against this server that produced
// 5 matches / 88 errors on a ~93-row column. Root
// cause: a single malformed entry anywhere in a batch (a blank cell serialized as
// JSON null, or any non-object value) either crashed the *entire* HTTP request
// with a 500, or — for the 1.0-draft array shape specifically — silently vanished
// during array unboxing, shortening "results" and shifting every later query's
// answer out of position. That exact mismatch is what OpenRefine's own
// batch-shape check reports as "No. of recon objects was less than no. of jobs".
describe('malformed batch entries do not crash or misalign the batch (OpenRefine hardening)', () => {
  let resultSchema

  before(() => {
    cy.fixture('schemas/1.0/reconciliation-result-batch.json').then((s) => { resultSchema = s })
  })

  it('1.0-draft: a null entry in "queries" keeps every other query at its correct position', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: {
        queries: [
          { type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] },
          null,
          { type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Schiller' }] },
        ],
      },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.results).to.have.length(3)
        // position 0 (Goethe) must still resolve to the real Goethe entity, not
        // be shifted by the null in between it and the Schiller query.
        expect(body.results[0].candidates[0].id).to.eq('kbga-actors-136')
        expect(body.results[1].candidates).to.have.length(0)
      })
  })

  it('1.0-draft: a non-object (scalar) entry in "queries" degrades to zero candidates instead of a 500', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: {
        queries: [
          { type: 'person', conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] },
          'Schiller',
        ],
      },
    })
      .validateSchema(resultSchema)
      .then(({ status, body }) => {
        expect(status).to.eq(200)
        expect(body.results).to.have.length(2)
        expect(body.results[1].candidates).to.have.length(0)
      })
  })

  it('0.2: a null value for a query key keeps every key in the response, without a 500', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: { q0: { query: 'Goethe' }, q1: null } },
    }).then(({ status, body }) => {
      expect(status).to.eq(200)
      expect(Object.keys(body)).to.have.length(2)
      expect(body.q1.result).to.have.length(0)
    })
  })

  it('0.2: a non-object (scalar) value for a query key degrades gracefully, without a 500', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: { q0: { query: 'Goethe' }, q1: 'Schiller' } },
    }).then(({ status, body }) => {
      expect(status).to.eq(200)
      expect(Object.keys(body)).to.have.length(2)
      expect(body.q1.result).to.have.length(0)
    })
  })

  it('a non-numeric "limit" falls back to the default instead of crashing with a 500', () => {
    cy.api({
      method: 'POST',
      url: '/api/reconcile',
      headers: { 'Content-Type': 'application/json' },
      body: { queries: [{ type: 'person', limit: 'abc', conditions: [{ matchType: 'name', propertyValue: 'Goethe' }] }] },
    })
      .validateSchema(resultSchema)
      .its('status')
      .should('eq', 200)
  })
})
