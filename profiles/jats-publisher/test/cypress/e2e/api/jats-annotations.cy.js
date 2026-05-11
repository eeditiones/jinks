const uploadAnnotations = () => {
    return cy.fixture('annotations.jats.xml', 'utf8').then(xml => {
        return cy.uploadXml('/api/upload/', 'annotations.jats.xml', xml)
            .then(({ status, body }) => {
                cy.wrap(status).should('eq', 200)
                cy.wrap(body).should('have.length', 1)
                cy.wrap(body).its('0.name').should('include', 'annotations.jats.xml')
            })
    })
}

const assertAnnotate = (payload, paraIndex, expectedXml) => {
    return cy.request({
        method: 'POST',
        url: '/api/annotations/merge/jats%2Fannotations.jats.xml',
        headers: { 'Content-Type': 'application/json' },
        body: payload
    }).then(({ status, body }) => {
        cy.wrap(status).should('eq', 200)
        cy.wrap(body.changes).should('have.length', 1)
        const doc = new DOMParser().parseFromString(body.content, 'application/xml')
        const para = selectPara(doc, paraIndex)
        const xml = new XMLSerializer().serializeToString(para)
        cy.wrap(xml).should('equal', expectedXml)
    })
}

const selectPara = (doc, idx) => {
    const xpath = `//*[local-name()='body']//*[local-name()='p'][${idx}]`
    const res = doc.evaluate(xpath, doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    return res.singleNodeValue
}

const selectFnGroup = (doc) => {
    const xpath = "//*[local-name()='back']//*[local-name()='fn-group']"
    const res = doc.evaluate(xpath, doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    return res.singleNodeValue
}

describe('/api/annotations/merge', () => {
    // Upload once; login before each test for a fresh session
    before(() => {
        return cy.login().then(() => uploadAnnotations())
    })
    beforeEach(() => {
        cy.login()
    })

    it('marks ipsum dolor in first paragraph as bold', () => {
        assertAnnotate({
            annotations: [
                { context: '1.6.2.3', start: 6, end: 17, text: 'ipsum dolor', type: 'hi', properties: { rend: 'bold' } }
            ]
        }, 1, '<p>Lorem <bold>ipsum dolor</bold> sit amet.</p>')
    })

    it('marks Karl Marx as person', () => {
        assertAnnotate({
            annotations: [
                { context: '1.6.2.7', start: 0, end: 9, text: 'Karl Marx', type: 'person', properties: { 'specific-use': 'Karl Marx' } }
            ]
        }, 3, '<p><named-content content-type="person" specific-use="Karl Marx">Karl Marx</named-content> was born in Trier.</p>')
    })

    it('marks Trier in 3rd paragraph as a place', () => {
        assertAnnotate({
            annotations: [
                { context: '1.6.2.7', start: 22, end: 27, text: 'Trier', type: 'place', properties: { 'specific-use': 'Trier' } }
            ]
        }, 3, '<p>Karl Marx was born in <named-content content-type="place" specific-use="Trier">Trier</named-content>.</p>')
    })

    it('adds a footnote after Trier', () => {
        const payload = {
            annotations: [
                {
                    context: '1.6.2.7',
                    start: 22,
                    end: 27,
                    text: 'Trier',
                    type: 'note',
                    properties: { content: '<p>City in Germany.</p>' }
                }
            ]
        }
        cy.request({
            method: 'POST',
            url: '/api/annotations/merge/jats%2Fannotations.jats.xml',
            headers: { 'Content-Type': 'application/json' },
            body: payload
        }).then(({ status, body }) => {
            cy.wrap(status).should('eq', 200)
            const doc = new DOMParser().parseFromString(body.content, 'application/xml')
            const para = selectPara(doc, 3)
            expect(para).not.to.be.null
            const xrefs = para.getElementsByTagName('xref')
            cy.wrap(xrefs.length).should('be.gte', 1)
            const xref = xrefs[0]
            cy.wrap(xref.getAttribute('ref-type')).should('eq', 'fn')
            const rid = xref.getAttribute('rid')
            cy.wrap(rid).should('be.a', 'string').and('not.be.empty')
            const paraXml = new XMLSerializer().serializeToString(para)
            cy.wrap(paraXml).should('include', 'Trier')
            cy.wrap(paraXml.indexOf('Trier') < paraXml.indexOf('<xref')).should('be.true')
            const fnGroup = selectFnGroup(doc)
            expect(fnGroup).not.to.be.null
            const fns = fnGroup.getElementsByTagName('fn')
            const fn = Array.from(fns).find(f => f.getAttribute('id') === rid)
            expect(fn).not.to.be.null
            const p = fn.getElementsByTagName('p')[0]
            expect(p).not.to.be.null
            cy.wrap(p.textContent).should('equal', 'City in Germany.')
        })
    })

    it('delete abbreviation', () => {
        assertAnnotate({
            annotations: [
                { type: 'delete', node: '1.6.2.5.2', context: '1.6.2.5' }
            ]
        }, 2, '<p>Lorem ipsum dolor sit amet.</p>')
    })
    after(() => {
        cy.logout()
    })
})