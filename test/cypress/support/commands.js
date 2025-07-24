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

// -- This is a parent command --

Cypress.Commands.add('loginApi', (fixtureName = 'user') => {
  cy.fixture(fixtureName).then((userData) => {
    cy.request({
      method: 'POST',
      url: '/api/login',
      headers: {
        'accept': 'application/json',
        'Content-Type': 'multipart/form-data'
      },
      form: true,
      body: {
        user: userData.user,
        password: userData.password
      },
      failOnStatusCode: false
    }).then((response) => {
      if (response.body && response.body.token) {
        cy.setCookie('token', response.body.token);
      }
    })
  })
})


Cypress.Commands.add('findFiles', (pattern) => {
  return cy.task('findFiles', { pattern })
})

Cypress.Commands.add('validateJsonSchema', (ajv, schema, data, filePath) => {
  const valid = ajv.validate(schema, data)
  if (!valid) {
    const errorDetails = ajv.errors.map(err => {
      return [
        `[${err.instancePath || '/'}]`,
        `Error: ${err.message}`,
        err.keyword ? `Keyword: ${err.keyword}` : '',
        err.params ? `Params: ${JSON.stringify(err.params)}` : ''
      ].filter(Boolean).join('\n')
    }).join('\n\n')

    expect(valid, `\n❌ Schema validation failed for: ${filePath}\n${'-'.repeat(60)}\n${errorDetails}\n${'-'.repeat(60)}\n`).to.be.true
  }
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


