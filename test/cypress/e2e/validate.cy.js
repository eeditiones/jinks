/// <reference types="cypress" />

const Ajv7 = require('ajv')
const Ajv4 = require('ajv-draft-04')
const addFormats = require('ajv-formats')

const ajv7 = new Ajv7({ allErrors: true, strict: false })
addFormats(ajv7)

const ajv4 = new Ajv4({ allErrors: true, strict: false })
addFormats(ajv4)

describe('Dynamic JSON Schema Validation', () => {
  const jinksSchema = 'schema/jinks.json'
  const jinksApi = 'modules/api.json'
  const openApiSchema = 'schema/openapi-3.0.json'

  before(() => {
    cy.readFile(openApiSchema).then(schema => {
      ajv4.addSchema(schema, 'https://spec.openapis.org/oas/3.0/schema/2021-09-28')
    })
  })

  it('validates jinks.json against the JSON Schema draft-07 meta-schema', () => {
    cy.readFile(jinksSchema).then(jinksSchema => {
      const metaSchema = ajv7.getSchema('http://json-schema.org/draft-07/schema').schema
      cy.validateJsonSchema(ajv7, metaSchema, jinksSchema, 'schema/jinks.json')
    })
  })

  it.skip('validates all config.json files against jinks.json', () => {
    cy.findFiles('profiles/**/config.json').then(configFiles => {
      cy.readFile(jinksSchema).then(schema => {
        configFiles.forEach(configPath => {
          cy.readFile(configPath).then(data => {
            cy.validateJsonSchema(ajv7, schema, data, configPath)
          })
        })
      })
    })
  })

  it('validates jinks api.json against OpenAPI 3.0.3 schema', () => {
    cy.readFile(jinksApi).then(data => {
      const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
      cy.validateJsonSchema(ajv4, schema, data, jinksApi)
    })
  })

  it('validates all api.tpl.json files against OpenAPI 3.0.3 schema', () => {
    const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
    cy.findFiles('**/*api.tpl.json').then(apiFiles => {
      apiFiles.forEach(apiPath => {
        cy.readFile(apiPath).then(data => {
          cy.validateJsonSchema(ajv4, schema, data, apiPath)
        })
      })
    })
  })
})