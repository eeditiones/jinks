/// <reference types="cypress" />

const Ajv7 = require('ajv')
const Ajv4 = require('ajv-draft-04')
const addFormats = require('ajv-formats')

const ajv7 = new Ajv7({ allErrors: true, strict: false })
addFormats(ajv7)

const ajv4 = new Ajv4({ allErrors: true, strict: false })
addFormats(ajv4)

describe('Static JSON Schema Validation', () => {
  const jinksSchema = 'schema/jinks.json'
  const jinksApi = 'modules/api.json'
  const openApiSchema = 'schema/openapi-3.0.json'

  before(() => {
    // Load and register OpenAPI schema
    cy.readFile(openApiSchema).then(schema => {
      ajv4.addSchema(schema, 'https://spec.openapis.org/oas/3.0/schema/2021-09-28')
    })

    // Load and register Jinks schema
    cy.readFile(jinksSchema).then(schema => {
      const cleanSchema = {
        $schema: 'http://json-schema.org/draft-07/schema',
        $id: 'https://tei-publisher.org/jinks/config/schema',
        type: 'object',
        properties: schema.properties,
        required: schema.required,
        additionalProperties: true
      }
      ajv7.addSchema(cleanSchema)
    })
  })
  describe('Jinks', () => {
    it('own schema should validate against the draft-07 meta-schema', () => {
      cy.readFile(jinksSchema).then(jinksSchema => {
        const metaSchema = ajv7.getSchema('http://json-schema.org/draft-07/schema').schema
        cy.validateJsonSchema(ajv7, metaSchema, jinksSchema, 'schema/jinks.json')
      })
    })

    it('profiles config.json should validate against main schema', () => {
      const schema = ajv7.getSchema('https://tei-publisher.org/jinks/config/schema')
      if (!schema) {
        throw new Error('Schema not found')
      }

      cy.findFiles('profiles/**/config.json').then(configFiles => {
        configFiles.forEach(configPath => {
          cy.readFile(configPath).then(data => {
            // Pre-validation logging only
            cy.log('Validating:', {
              file: configPath,
              required: {
                id: { present: 'id' in data, value: data.id },
                type: { present: 'type' in data, value: data.type },
                label: { present: 'label' in data, value: data.label }
              }
            })
            cy.validateJsonSchema(ajv7, schema.schema, data, configPath)
          })
        })
      })
    })
  })

  describe('openApi', () => {

    it('jinks api.json should validate agains OpenAPI 3.0.3 schema', () => {
      cy.readFile(jinksApi).then(data => {
        const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
        cy.validateJsonSchema(ajv4, schema, data, jinksApi)
      })
    })

    it('jinks deploy-api.json should validate agains OpenAPI 3.0.3 schema', () => {
      const jinksDeploy ='modules/deploy-api.json'
      cy.readFile(jinksDeploy).then(data => {
        const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
        cy.validateJsonSchema(ajv4, schema, data, jinksDeploy)
      })
    })

    it('profiles api.tpl.json should validate agains OpenAPI 3.0.3 schema', () => {
      const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
      cy.findFiles('**/*api.tpl.json').then(apiFiles => {
        apiFiles.forEach(apiPath => {
          cy.readFile(apiPath).then(data => {
            cy.validateJsonSchema(ajv4, schema, data, apiPath)
          })
        })
      })
    })

    it('custom-api.json (docs) should validate agains OpenAPI 3.0.3 schema', () => {
      const customApi = 'profiles/docs/modules/custom-api.json'
      cy.readFile(customApi).then(data => {
        const schema = ajv4.getSchema('https://spec.openapis.org/oas/3.0/schema/2021-09-28').schema
        cy.validateJsonSchema(ajv4, schema, data, customApi)
      })
    })
  })
})