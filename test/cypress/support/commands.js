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
//
// -- This is a parent command --

// ...existing code...

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

// ...existing code...
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