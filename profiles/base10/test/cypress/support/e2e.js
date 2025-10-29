// ***********************************************************
// This example support/e2e.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands'

// Universal intercepts for all GUI tests
// These stubs prevent hanging on API calls that aren't relevant to most tests
beforeEach(() => {
  // Stub login attempts to prevent authentication popups in non-auth tests
  cy.intercept('POST', '/api/login/**', { statusCode: 401, body: { error: 'Unauthorized' } }).as('loginStub')
  
  // Stub timeline API to prevent hanging when timeline component tries to load
  cy.intercept('GET', '/api/timeline/**', { statusCode: 200, body: { timeline: [] } }).as('timelineStub')
})
