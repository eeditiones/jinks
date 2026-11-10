/// <reference types="cypress" />

// Static check of the OpenAPI specs shipped with the profiles (i.e. the APIs of generated apps):
// every operation which may modify data must be protected by "x-constraints", and constraints
// must only use the keys understood by roaster ("groups" and "user"). Roaster silently ignores
// any other key, e.g. "group", which would leave the endpoint unprotected.

// Write operations which are intentionally open to everyone. Keys are "METHOD path".
const PUBLIC_WRITE_OPERATIONS = [
  'POST /api/login',
  'POST /api/lint',            // compiles, but does not execute, an ODD code snippet
  'POST /api/preview',         // transforms the XML sent in the request body
  'POST /api/convert',         // converts an uploaded docx without storing it
  'POST /api/nlp/strings',     // converts string matches to annotations
  'POST /api/annotations/occurrences',
  'POST /api/annotations/merge/{path}' // preview only, saving requires PUT
]

const WRITE_METHODS = ['post', 'put', 'patch', 'delete']
const CONSTRAINT_KEYS = ['groups', 'user']

// Remove jinks template syntax so the template files can be parsed as JSON
const stripTemplate = (text) =>
  text
    .replace(/\[#[\s\S]*?#\]/g, '')
    .replace(/\[%[\s\S]*?%\]/g, '')
    .replace(/\[\[[\s\S]*?\]\]/g, 'X')

describe('API access constraints', () => {
  let specs = []

  before(() => {
    cy.task('findFiles', { pattern: 'profiles/**/modules/**/*api*.json' }).then((files) => {
      files
        .filter((file) => !file.includes('/node_modules/'))
        .forEach((file) => {
          cy.task('readText', file).then((text) => {
            specs.push({ file, spec: JSON.parse(stripTemplate(text)) })
          })
        })
    })
  })

  it('finds the API specs', () => {
    expect(specs.length).to.be.greaterThan(0)
    expect(specs.map((s) => s.file)).to.include('profiles/base10/modules/lib/api.tpl.json')
  })

  it('protects all write operations with x-constraints', () => {
    const unprotected = []
    specs.forEach(({ file, spec }) => {
      Object.entries(spec.paths || {}).forEach(([path, operations]) => {
        WRITE_METHODS.forEach((method) => {
          const op = operations[method]
          const key = `${method.toUpperCase()} ${path}`
          if (op && !op['x-constraints'] && !PUBLIC_WRITE_OPERATIONS.includes(key)) {
            unprotected.push(`${file}: ${key} (${op.operationId})`)
          }
        })
      })
    })
    expect(unprotected, 'write operations without x-constraints').to.be.empty
  })

  it('only uses constraint keys known to roaster', () => {
    const invalid = []
    specs.forEach(({ file, spec }) => {
      Object.entries(spec.paths || {}).forEach(([path, operations]) => {
        Object.entries(operations).forEach(([method, op]) => {
          const constraints = op && op['x-constraints']
          if (!constraints) return
          const unknown = Object.keys(constraints).filter((k) => !CONSTRAINT_KEYS.includes(k))
          const badGroups = constraints.groups !== undefined && !Array.isArray(constraints.groups)
          if (unknown.length || badGroups) {
            invalid.push(`${file}: ${method.toUpperCase()} ${path} ${JSON.stringify(constraints)}`)
          }
        })
      })
    })
    expect(invalid, 'invalid x-constraints').to.be.empty
  })
})
