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


