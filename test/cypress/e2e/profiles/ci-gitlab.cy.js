/// <reference types="cypress" />

const yaml = require('js-yaml')
const Ajv7 = require('ajv')
const addFormats = require('ajv-formats')

const ajv7 = new Ajv7({ allErrors: true, strict: false })
addFormats(ajv7)

describe('GitLab CI Templates', () => {
  let gitlabCiSchema

  before(() => {
    // Load GitLab CI schema from GitLab repository
    cy.request({
      url: 'https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json',
      failOnStatusCode: false
    }).then(res => {
      if (res.status !== 200) {
        cy.log('Failed to load GitLab CI schema:', res.status)
        cy.log('Response body:', res.body)
        throw new Error(`Failed to load GitLab CI schema: ${res.status}`)
      }
      // Cypress automatically parses JSON, but check if it's a string
      let schemaData = res.body
      if (typeof schemaData === 'string') {
        try {
          schemaData = JSON.parse(schemaData)
        } catch (e) {
          cy.log('Failed to parse schema as JSON:', e.message)
          cy.log('Response body (first 500 chars):', schemaData.substring(0, 500))
          throw new Error(`GitLab CI schema is not valid JSON: ${e.message}`)
        }
      }
      // Validate it's a schema object
      if (!schemaData || typeof schemaData !== 'object' || Array.isArray(schemaData)) {
        cy.log('Invalid schema response type:', typeof schemaData)
        cy.log('Response body (first 500 chars):', JSON.stringify(schemaData).substring(0, 500))
        throw new Error('GitLab CI schema is not a valid object')
      }
      gitlabCiSchema = schemaData
      ajv7.addSchema(gitlabCiSchema, 'gitlab-ci-schema')
    })
  })
  beforeEach(() => {
    cy.loginApi()
  })

  // Helper function to validate YAML structure
  const validateYaml = (yamlString) => {
    try {
      const parsed = yaml.load(yamlString)
      return { valid: true, parsed }
    } catch (error) {
      return { valid: false, error: error.message }
    }
  }

  describe('GitLab CI template', () => {
    let gitlabTemplate

    before(() => {
      cy.readFile('profiles/ci/.gitlab-ci.tpl.yml').then(template => {
        gitlabTemplate = template
      })
    })

    it('POST /api/templates expands GitLab template without externalXar (no blank lines)', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: gitlabTemplate,
          params: {
            docker: {
              ports: { http: 8080 }
            }
          },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'object')
        cy.wrap(res.body).should('have.property', 'result')
        cy.wrap(res.headers).its('content-type').should('include', 'application/json')

        const result = res.body.result
        const lines = result.split('\n')
        
        // Find export DOCKER_BUILDKIT line and verify 'docker buildx build' appears on same or next line
        const dockerBuildkitIndex = lines.findIndex(line => line.includes('export DOCKER_BUILDKIT=1'))
        cy.wrap(dockerBuildkitIndex).should('be.greaterThan', -1)
        
        // 'docker buildx build' should be on the same line (after [% endif %]) or the next line
        const dockerBuildkitLine = lines[dockerBuildkitIndex]
        const nextLine = dockerBuildkitIndex + 1 < lines.length ? lines[dockerBuildkitIndex + 1] : ''
        cy.wrap(dockerBuildkitLine.includes('docker buildx build') || nextLine.includes('docker buildx build')).should('be.true', 'docker buildx build should appear on same line or next line after export DOCKER_BUILDKIT=1')
        
        // If on next line, verify no blank lines in between
        if (nextLine.includes('docker buildx build')) {
          cy.wrap(nextLine.trim()).should('not.be.empty')
        }

        // Validate YAML structure
        const validation = validateYaml(result)
        cy.wrap(validation.valid).should('be.true', `YAML validation failed: ${validation.error || 'unknown error'}`)
        cy.wrap(validation.parsed).should('have.property', 'stages')
        cy.wrap(validation.parsed).should('have.property', 'variables')

        // Check for error strings in output
        cy.wrap(result.toLowerCase()).should('not.include', 'error:')
        cy.wrap(result).should('not.match', /\[% .* %\]/, 'Template blocks should be processed, not left in output')

        // Save output file for manual inspection
        cy.writeFile('test/cypress/downloads/gitlab-without-externalxar.yml', result)
      })
    })

    it('POST /api/templates expands GitLab template with CI_JOB_TOKEN', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: gitlabTemplate,
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'CI_JOB_TOKEN'
                }
              }
            }
          },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        
        // Save output file for debugging even if test fails
        cy.writeFile('test/cypress/downloads/gitlab-with-ci-job-token.yml', res.body.result)
        
        cy.wrap(res.body.result).should('include', 'CI_JOB_TOKEN')
        cy.wrap(res.body.result).should('include', '--secret id=CI_JOB_TOKEN')

        // Validate YAML structure
        const validation = validateYaml(res.body.result)
        if (!validation.valid) {
          cy.log('YAML validation error:', validation.error)
          cy.log('First 500 chars of result:', res.body.result.substring(0, 500))
        }
        cy.wrap(validation.valid).should('be.true', `YAML validation failed: ${validation.error || 'unknown error'}`)

        // Check for actual error messages (not commands that contain "error" or "failed")
        // Look for error patterns at start of line, not in shell conditions or YAML keys
        const errorPattern = /^(Error|ERROR|error):\s|^Error while|^failed\s|^Failed\s|^FAILED\s/
        cy.wrap(res.body.result.split('\n').some(line => {
          const trimmed = line.trim()
          return errorPattern.test(trimmed) && !trimmed.includes('allow_failure') && !trimmed.includes('CI_JOB_STATUS')
        })).should('be.false', 'Should not contain error messages')
        
        // Check that template blocks are processed
        cy.wrap(res.body.result).should('not.include', '[% if')
        cy.wrap(res.body.result).should('not.include', '[% else')
        cy.wrap(res.body.result).should('not.include', '[% endif')
        cy.wrap(res.body.result).should('not.include', '[% for')
        cy.wrap(res.body.result).should('not.include', '[% endfor')

        // Save output file for manual inspection
        cy.writeFile('test/cypress/downloads/gitlab-with-ci-job-token.yml', res.body.result)
      })
    })

    it('POST /api/templates expands GitLab template with custom token', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: gitlabTemplate,
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'CUSTOM_TOKEN'
                }
              }
            }
          },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        
        // Save output file for debugging even if test fails
        cy.writeFile('test/cypress/downloads/gitlab-with-custom-token.yml', res.body.result)
        
        cy.wrap(res.body.result).should('include', 'CUSTOM_TOKEN')
        cy.wrap(res.body.result).should('include', 'export CUSTOM_TOKEN')
        cy.wrap(res.body.result).should('include', '--secret id=CUSTOM_TOKEN')

        // Validate YAML structure
        const validation = validateYaml(res.body.result)
        if (!validation.valid) {
          cy.log('YAML validation error:', validation.error)
          cy.log('First 500 chars of result:', res.body.result.substring(0, 500))
        }
        cy.wrap(validation.valid).should('be.true', `YAML validation failed: ${validation.error || 'unknown error'}`)

        // Check for actual error messages (not commands that contain "error" or "failed")
        // Look for error patterns at start of line, not in shell conditions or YAML keys
        const errorPattern = /^(Error|ERROR|error):\s|^Error while|^failed\s|^Failed\s|^FAILED\s/
        cy.wrap(res.body.result.split('\n').some(line => {
          const trimmed = line.trim()
          return errorPattern.test(trimmed) && !trimmed.includes('allow_failure') && !trimmed.includes('CI_JOB_STATUS')
        })).should('be.false', 'Should not contain error messages')
        
        // Check that template blocks are processed
        cy.wrap(res.body.result).should('not.include', '[% if')
        cy.wrap(res.body.result).should('not.include', '[% else')
        cy.wrap(res.body.result).should('not.include', '[% endif')
        cy.wrap(res.body.result).should('not.include', '[% for')
        cy.wrap(res.body.result).should('not.include', '[% endfor')

        // Save output file for manual inspection
        cy.writeFile('test/cypress/downloads/gitlab-with-custom-token.yml', res.body.result)
      })
    })

    it('generated GitLab CI workflows validate against official JSON schema', () => {
      // Test all three scenarios: no externalXar, CI_JOB_TOKEN, and custom token
      const scenarios = [
        {
          name: 'without externalXar',
          params: {
            docker: {
              ports: { http: 8080 }
            }
          }
        },
        {
          name: 'with CI_JOB_TOKEN',
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'CI_JOB_TOKEN'
                }
              }
            }
          }
        },
        {
          name: 'with custom token',
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'CUSTOM_TOKEN'
                }
              }
            }
          }
        }
      ]

      scenarios.forEach(scenario => {
        cy.request({
          method: 'POST',
          url: '/api/templates',
          headers: { 'content-type': 'application/json' },
          body: {
            template: gitlabTemplate,
            params: scenario.params,
            mode: 'text'
          }
        }).then(res => {
          cy.wrap(res).its('status').should('eq', 200)
          
          // Parse YAML to JSON for schema validation
          const ciYaml = res.body.result
          const ciJson = yaml.load(ciYaml)
          
          // Validate against GitLab CI schema
          const schema = ajv7.getSchema('gitlab-ci-schema')
          if (!schema) {
            throw new Error('GitLab CI schema not loaded')
          }
          
          cy.validateJsonSchema(ajv7, schema.schema, ciJson, `GitLab CI workflow (${scenario.name})`)
        })
      })
    })
  })
})
