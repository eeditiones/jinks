// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
import 'cypress-ajv-schema-validator';

// Simple, idiomatic auth helpers using Cypress patterns

// Cache the authenticated session across specs to speed up runs
// See: https://docs.cypress.io/api/commands/session
Cypress.Commands.add('login', (fixtureName = 'user') => {
  return cy.fixture(fixtureName).then(({ user, password }) => {
    const baseUrl = Cypress.config('baseUrl')
    const origin = baseUrl ? new URL(baseUrl).origin : null
    if (!origin) {
      throw new Error('baseUrl must be configured in Cypress config. Set it in cypress.config.cjs')
    }
    return cy.request({
      method: 'POST',
      url: '/api/login',
      form: true,
      body: { user, password },
      headers: { Origin: origin, Accept: 'application/json' }
    }).its('status').should('eq', 200)
  })
})

Cypress.Commands.add('logout', () => {
  // Best-effort server logout, then clear client-side cookies
  cy.request({
    method: 'POST',
    url: '/api/login',
    qs: { logout: 'true' },
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    failOnStatusCode: false
  })
  cy.clearCookies()
})

// Lightweight wrapper for API calls that need an Origin header
// Usage:
//  cy.api('/api/search')
//  cy.api({ method: 'POST', url: '/api/odd', qs: {...} })
Cypress.Commands.add('api', (opts) => {
  const options = typeof opts === 'string' ? { url: opts } : { ...opts }
  const baseUrl = Cypress.config('baseUrl')
  const origin = baseUrl ? new URL(baseUrl).origin : null
  if (!origin) {
    throw new Error('baseUrl must be configured in Cypress config. Set it in cypress.config.cjs')
  }
  options.headers = { Origin: origin, ...(options.headers || {}) }
  return cy.request(options)
})

// Multipart XML upload helper
Cypress.Commands.add('uploadXml', (url, filename, xml, opts = {}) => {
  const boundary = '----CYPRESSFORM' + Date.now()
  const body = [
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="files[]"; filename="${filename}"\r\n` +
    'Content-Type: application/xml\r\n\r\n' +
    xml + '\r\n' +
    `--${boundary}--\r\n`
  ].join('')
  const headers = { 'Content-Type': `multipart/form-data; boundary=${boundary}`, Accept: 'application/json', ...(opts.headers || {}) }
  return cy.api({ method: 'POST', url, headers, body, failOnStatusCode: opts.failOnStatusCode })
})


Cypress.Commands.add('findFiles', (pattern) => {
  return cy.task('findFiles', { pattern })
})

Cypress.Commands.add('validateJsonSchema', (ajv, schema, data, filePath) => {
  const valid = ajv.validate(schema, data)
  if (!valid) {
    const formattedErrors = ajv.errors.map(error => {
      const path = error.instancePath.slice(1)
      const propertySchema = schema.properties?.[path]
      
      return {
        path: path || 'root',
        value: error.instancePath ? 
          error.instancePath.split('/').reduce((obj, key) => obj?.[key], data) 
          : data,
        message: error.message,
        keyword: error.keyword,
        expectedType: propertySchema?.type,
        format: propertySchema?.format,
        enum: propertySchema?.enum
      }
    })

    const errorMessage = [
      `\n❌ Schema validation failed for: ${filePath}`,
      '-'.repeat(60),
      'Validation errors:',
      JSON.stringify(formattedErrors, null, 2),
      '-'.repeat(60),
      'Expected format:',
      schema.required ? `Required fields: ${schema.required.join(', ')}` : '',
      schema.properties ? 
        Object.entries(schema.properties)
          .map(([key, prop]) => 
            `- ${key}: ${prop.type}${prop.format ? ` (${prop.format})` : ''}${prop.enum ? ` [${prop.enum.join('|')}]` : ''}`)
          .join('\n')
        : ''
    ].filter(Boolean).join('\n')

    expect(valid, errorMessage).to.be.true
  }
})

Cypress.Commands.add('logout', () => {
  cy.request({
    method: 'POST',
    url: '/api/login',
    qs: { logout: 'true' },
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    failOnStatusCode: false
  })
  cy.clearCookies()
})

//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })


