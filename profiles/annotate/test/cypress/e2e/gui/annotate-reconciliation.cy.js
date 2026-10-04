// GUI test: reconciling an entity from inside the web annotation editor, against this
// profile's own /api/reconcile endpoint.
//
// Scope: covers the "click an already-tagged entity -> edit -> the reconciliation
// search fires against our endpoint -> a real candidate is shown -> selecting it links
// the entity" click path. This flow, wired up correctly, once queried
// https://api.metagrid.ch/ instead of localhost -- root cause: tei-publisher-components'
// createConnectors() silently falls back to the unrelated Metagrid connector for ANY
// unrecognized `connector` attribute value (a typo like connector="Reconciliation"
// instead of the exact "ReconciliationService" would trigger this, with no error).
// These tests are a regression guard against exactly that: they assert the actual
// request URL, not just "some request happened".
//
// NOT covered here: tagging a brand-new entity by selecting raw, previously-untagged
// text in the document. That flow drives the browser's native Selection API inside a
// Shadow DOM (pb-view-annotate debounces `selectionchange`/`mouseup` and tracks
// selection state manually -- see pb-view-annotate.js's _selectionChanged), which
// Cypress has no first-class command for; it would need low-level
// cy.window().its('...').invoke('getSelection')-style scripting and is meaningfully
// more fragile than the click-to-edit flow tested here. Worth a follow-up if the
// "create new annotation" path specifically needs coverage.
//
// Uses real demo data (the Karl Barth sermon 27004.xml, "Thurneysen" persName, entity
// id kbga-actors-403) rather than a synthetic fixture -- demo-data is a required
// `extends` for any app running these tests, so this is stable, not incidental
// live-app state, matching the convention already used by this profile's own API tests
// (reconcile.cy.js's Goethe/Dantiscus examples).
describe('Web annotation editor: reconciling an entity against our own endpoint', () => {
  const docPath = 'sermons/27004.xml';
  const annotateUrl = `/${docPath}?template=annotate-tei.html&odd=annotations&view=single`;
  const auth = { username: 'tei', password: 'simple' };

  before(() => {
    // Idempotently confirm the "person" authority is wired to our own ReconciliationService
    // connector (nested inside Custom, per the shipped annotate-tei.html - see the profile
    // source's own authority-config template) with `fields` configured (see
    // tei-publisher-components' Registry.buildProperties/parseFieldsConfig) so a selected
    // match's escaped name, id, and (fetched via /extend) GND identifier land in three separate
    // output attributes instead of the id alone going to the reference/key field. This is
    // shipped by the profile itself now, not applied ad hoc here - this just guards against
    // running against a stale/differently-configured app. Note: the *editable page*
    // (templates/pages/annotate.html) has no pb-authority elements of its own - it's a base
    // template extended by templates/pages/annotate-tei.html (requested via
    // ?template=annotate-tei.html, not annotate.html - see annotateUrl below), which is where
    // authority-config actually lives.
    const xq = `
      declare namespace html="http://www.w3.org/1999/xhtml";
      let $doc := doc("/db/apps/tp-reconc/templates/pages/annotate-tei.html")
      let $person := $doc//*[local-name() = 'pb-authority'][@name = 'person']
      return
        if ($person/@fields = "key=label,ref=id,gnd=extend:gnd") then "already-wired"
        else (
          (: Update the @fields attribute only - $person is the outer connector="Custom"
             element that wraps a nested GND connector plus a nested ReconciliationService
             connector (see annotate-tei.html); replacing the whole element here (as an
             earlier version of this guard did) would silently drop that nesting and
             regress to a bare ReconciliationService-only connector. :)
          update value $person/@fields with "key=label,ref=id,gnd=extend:gnd",
          "updated"
        )
    `;
    cy.request({
      method: 'POST',
      url: 'http://localhost:8080/exist/rest/db',
      auth,
      headers: { 'Content-Type': 'application/xml' },
      body: `<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no"><text><![CDATA[${xq}]]></text></query>`,
    }).its('status').should('eq', 200);
  });

  it('editing a tagged person entity queries this app\'s own /api/reconcile, not an external service', () => {
    cy.intercept('**/api/reconcile**').as('reconcile');

    cy.visit(annotateUrl, { auth });
    cy.wait(3000); // let pb-view-annotate finish its initial render before interacting
    cy.get('.annotation.authority').contains('Thurneysen').scrollIntoView().click({ force: true });
    cy.wait(500); // Tippy.js popup mount
    cy.get('paper-icon-button[icon="icons:create"]').click({ force: true });

    cy.wait('@reconcile').then((interception) => {
      // The actual regression this guards: a misconfigured/unrecognized connector
      // name silently falls back to https://api.metagrid.ch/ with no error.
      expect(interception.request.url).to.match(/^http:\/\/localhost:8080\/exist\/apps\/tp-reconc\/api\/reconcile/);
      expect(interception.request.url).not.to.include('metagrid');
      expect(interception.response.statusCode).to.eq(200);
      // The connector's own query-id counter (q1, q2, ...) isn't stable across runs
      // (it can fire more than one debounced query while the search field is
      // pre-filled), so read whichever single query key the response actually used
      // rather than assuming "q1".
      const [query] = Object.values(interception.response.body || {});
      const candidates = query?.result || [];
      if (candidates.length === 0) {
        // an early, still-empty-query debounce tick can legitimately return zero
        // candidates; the UI-level assertion below is the real check that a usable
        // result eventually renders.
        return;
      }
      expect(candidates[0].id).to.eq('kbga-actors-403');
      expect(candidates[0].name).to.include('Thurneysen');
    });

    // The candidate list renders inside the popup's scrollable .info container (capped
    // at max-height so a long entity preview doesn't blow up the page - see annotate.css)
    // below whatever detail content the earlier click-to-view popup already rendered, so
    // it can start out below the fold. scrollIntoView() first, same as every other
    // candidate-list interaction in this file, rather than asserting visibility in place.
    cy.contains('Thurneysen, Eduard (1888-1974)').scrollIntoView().should('be.visible');
  });

  it('selecting the returned candidate links the entity to that candidate\'s id', () => {
    cy.intercept('**/api/reconcile**').as('reconcile');

    cy.visit(annotateUrl, { auth });
    cy.wait(3000);
    cy.get('.annotation.authority').contains('Thurneysen').scrollIntoView().click({ force: true });
    cy.wait(500);
    cy.get('paper-icon-button[icon="icons:create"]').click({ force: true });
    cy.wait('@reconcile');

    // Select via the dedicated "link to" button, not the candidate's label text: when
    // the service's manifest resolves a view URL for the candidate, the label is ALSO
    // wrapped in its own <a href> (opens the entity's view page in a new tab) --
    // cy.contains(label).click() is ambiguous between the two and can hit the link
    // instead of actually selecting the candidate. The button carries a stable
    // title="link to" regardless of whether a view link is present.
    cy.contains('li', 'Thurneysen, Eduard (1888-1974)').find('button[title="link to"]').click({ force: true });
    cy.wait(1000); // selecting a candidate triggers a save round-trip (annotations/occurrences)

    // The "Annotation Details" panel shows the linked entity's id inside an <input>
    // value, not as plain text content -- cy.contains() only matches rendered text
    // nodes, so check input values directly instead.
    cy.get('input').should(($inputs) => {
      const values = [...$inputs].map((el) => el.value);
      expect(values, 'input values on the page').to.include('kbga-actors-403');
    });
  });
});

// Regression coverage for the general field-mapping mechanism (see
// tei-publisher-components' Registry.buildProperties/parseFieldsConfig): an admin
// can configure, via the `fields` attribute set
// on the person authority in annotate-tei.html (see this file's own before() hook
// above), which of a match's fields end up in which output attribute, instead of
// only ever the id going to a single reference/key attribute. Uses a different demo
// entity than the tests above ("Sailer, Hieronymus" / gnd-137224435, in
// demo/CIDTC-3823-cortez.xml) specifically because it has a real, non-empty GND
// identifier available via /extend, letting this test also exercise the
// `extend:propertyId` field source end-to-end, not just id/label.
describe('Web annotation editor: mapping a match\'s fields to output attributes', () => {
  const annotateUrl = '/demo/CIDTC-3823-cortez.xml?template=annotate-tei.html&odd=annotations&view=single';
  const auth = { username: 'tei', password: 'simple' };

  it('writes the escaped name, id, and an /extend-fetched property to three separate attributes', () => {
    cy.visit(annotateUrl, { auth });
    cy.wait(4000);
    cy.get('.annotation.authority').contains('Ger').scrollIntoView().click({ force: true });
    cy.wait(500);
    cy.get('paper-icon-button[icon="icons:create"]').click({ force: true });
    cy.wait(1000);

    // The pencil-click auto-fills the search box with the clicked span's own visible
    // text ("Gerónimo Sailer", given-name-first), which genuinely doesn't score a
    // match against this entity's "Sailer, Hieronymus" (surname-first) label via
    // either /suggest/entity or the full /reconcile endpoint -- confirmed directly
    // against both endpoints, not a bug in this test. Type an explicit search term
    // that does match instead of relying on the auto-filled one.
    cy.get('pb-authority-lookup').shadow().find('input#query').clear().type('Sailer');
    cy.wait(1500);
    cy.contains('li', 'Sailer, Hieronymus').find('button[title="link to"]').click({ force: true });
    cy.wait(1500);

    cy.get('input[name="key"]').should('have.value', 'Sailer-Hieronymus');
    cy.get('input[name="ref"]').should('have.value', 'gnd-137224435');
    // "gnd" is populated via a live round-trip to lobid.org (GND.fetchExtend ->
    // getRecord), not from data the candidate list already had - give it more room
    // than the default 4s retry window before treating a slow lobid.org response as
    // a real failure.
    cy.get('input[name="gnd"]', { timeout: 12000 }).should('have.value', 'https://d-nb.info/gnd/137224435');
  });
});

// Confirms field-mapping (and the matching keyMap entry needed for the click-to-view detail
// popup, see the describe block below) is not person-only: the mechanism itself lives entirely
// in Registry.buildProperties (tei-publisher-components), shared by every connector including
// "Custom" (which "place"/"organization"/"work" use, wrapping the local register plus a
// GND/GeoNames fallback) - only the demo's own annotate-tei.html config decided which types
// actually turn it on. Uses "place" specifically because it has real, searchable local register
// data (unlike organization/work, which have none in this demo) - same mechanism though, so this
// stands in for all three.
describe('Web annotation editor: field-mapping and detail popups work for types other than person', () => {
  const annotateUrl = '/demo/CIDTC-3823-cortez.xml?template=annotate-tei.html&odd=annotations&view=single';
  const auth = { username: 'tei', password: 'simple' };

  it('writes the escaped name, id, and an /extend-fetched GeoNames link to three separate attributes for a "place" match', () => {
    cy.visit(annotateUrl, { auth });
    cy.wait(4000);
    // "Castilla" (unlike "México", which is also a substring of a second, separately
    // annotated "gran ciudad de México" span in this same document) appears exactly once,
    // so cy.contains() can't ambiguously match the wrong occurrence.
    cy.get('.annotation.authority').contains('Castilla').scrollIntoView().click({ force: true });
    cy.wait(500);
    cy.get('paper-icon-button[icon="icons:create"]').click({ force: true });
    cy.wait(1000);

    cy.get('pb-authority-lookup').shadow().find('input#query').clear().type('Madrid');
    cy.wait(1500);
    cy.contains('li', 'Madrid').find('button[title="link to"]').click({ force: true });
    // extend:link resolves via a real, live GeoNames.fetchExtend() call (geonameId 3117735 is a
    // genuine GeoNames id, not just a local-register convention), so give it more time than the
    // plain save round-trip alone would need.
    cy.wait(3000);

    cy.get('input[name="key"]').should('have.value', 'Madrid');
    cy.get('input[name="ref"]').should('have.value', 'geo-3117735');
    cy.get('input[name="link"]').should('have.value', 'https://www.geonames.org/3117735');
  });

  // Sets up the linked state directly via XQuery rather than depending on the search-and-select
  // test above having actually persisted its selection to the document -- Cypress's forced-click
  // selection flow reliably updates the *form*, but does not reliably persist to the saved
  // document for a re-selection of an already-annotated span, for any type including "person"
  // (a real, unforced user interaction does persist correctly, so this looks like a Cypress
  // force-click limitation, not a product bug). That's orthogonal to what this specific test
  // needs to check, which is only whether the detail popup correctly reads @ref once it's set.
  it('the detail popup for a "place" linked via @ref shows the real preview, not "Entity not found"', () => {
    const xq = `
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      let $p := doc("/db/apps/tp-reconc/data/demo/CIDTC-3823-cortez.xml")//tei:placeName[contains(., "Castilla")][1]
      return (
        update insert attribute ref { "geo-3117735" } into $p,
        update value $p/@key with "Madrid",
        "done"
      )
    `;
    cy.request({
      method: 'POST',
      url: 'http://localhost:8080/exist/rest/db',
      auth,
      headers: { 'Content-Type': 'application/xml' },
      body: `<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no"><text><![CDATA[${xq}]]></text></query>`,
    }).its('status').should('eq', 200);

    cy.visit(annotateUrl, { auth });
    cy.wait(4000);
    cy.get('.annotation.authority').contains('Castilla').scrollIntoView().click({ force: true });
    cy.wait(1000);

    cy.get('.info').should(($info) => {
      const text = $info.text();
      expect(text, 'detail popup content').not.to.include('not found');
      expect(text, 'detail popup content').to.include('Madrid');
    });
  });
});

// Regression coverage: with fields="key=label,ref=id,..." in effect (see the describe
// block above), clicking on an already-linked entity to view its read-only detail popup
// showed "Entity not found" instead of the entity's actual preview/properties. Root
// cause: pb-view-annotate's own detail-lookup reads the id from whichever annotation
// property the "key"/"key-map" attribute names (default "key", i.e. persName/@key) --
// correct under the OLD single-attribute convention where @key held the id, but @key now
// holds the *label* under the new field-mapping convention, with the id in @ref instead.
// Fixed via a "person": "ref" entry in the app's key-map (see tei-publisher-jinks
// profiles/annotate/config.json's features.annotate.configs.tei.keyMap, wired onto
// <pb-view-annotate key-map="..."> in annotate.html) -- pb-view-annotate.js's own
// getKey(type) already supported this per-type override, it just wasn't configured.
// (A related, deeper gap -- entities that predate any keyMap/fields config and only ever
// had @key, never @ref -- is covered separately by pb-view-annotate's getId() fallback,
// exercised by the "Thurneysen" tests in the first describe block above.) Sets up the
// linked state directly via XQuery against an existing, pristine persName ("Peter",
// kbga-actors-27) so this test is self-contained rather than depending on hand-created
// state that doesn't survive a clean app regeneration.
describe('Web annotation editor: viewing an already-linked entity\'s detail popup', () => {
  const annotateUrl = '/sermons/27003.xml?template=annotate-tei.html&odd=annotations&view=single';
  const auth = { username: 'tei', password: 'simple' };

  before(() => {
    const xq = `
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      let $p := doc("/db/apps/tp-reconc/data/sermons/27003.xml")//tei:persName[@key = "kbga-actors-27"][1]
      return (
        if ($p/@ref) then () else update insert attribute ref { "kbga-actors-27" } into $p,
        update value $p/@key with "Barth-Peter",
        "done"
      )
    `;
    cy.request({
      method: 'POST',
      url: 'http://localhost:8080/exist/rest/db',
      auth,
      headers: { 'Content-Type': 'application/xml' },
      body: `<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no"><text><![CDATA[${xq}]]></text></query>`,
    }).its('status').should('eq', 200);
  });

  it('shows the entity\'s real preview, not "Entity not found"', () => {
    cy.visit(annotateUrl, { auth });
    cy.wait(4000);
    cy.get('.annotation.authority').contains('Peter').scrollIntoView().click({ force: true });
    cy.wait(1000);

    cy.get('.info').should(($info) => {
      const text = $info.text();
      expect(text, 'detail popup content').not.to.include('not found');
      expect(text, 'detail popup content').to.include('Barth');
    });
  });
});
