/// <reference types="cypress" />

const yaml = require('js-yaml')
const Ajv7 = require('ajv')
const addFormats = require('ajv-formats')

const ajv7 = new Ajv7({ allErrors: true, strict: false })
addFormats(ajv7)

describe('GitHub Actions CI Templates', () => {
  let githubWorkflowSchema

  before(() => {
    // Load GitHub Actions workflow schema from JSON Schema Store
    cy.request('https://www.schemastore.org/github-workflow.json').then(res => {
      githubWorkflowSchema = res.body
      ajv7.addSchema(githubWorkflowSchema, 'https://json.schemastore.org/github-workflow.json')
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

  describe('GitHub Actions workflow template', () => {
    let githubTemplate

    before(() => {
      cy.readFile('profiles/ci/.github/workflows/ci.tpl.yml').then(template => {
        githubTemplate = template
      })
    })

    it('POST /api/templates expands GitHub template without externalXar (no blank lines)', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: githubTemplate,
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
        
        // Find DOCKER_BUILDKIT line and verify 'run: |' appears in the result
        // Note: We check for valid YAML structure below, which is the real validation
        const dockerBuildkitIndex = lines.findIndex(line => line.includes('DOCKER_BUILDKIT: 1'))
        cy.wrap(dockerBuildkitIndex).should('be.greaterThan', -1)
        
        // Verify 'run: |' appears somewhere after DOCKER_BUILDKIT (within reasonable distance)
        const runIndex = lines.findIndex((line, idx) => idx > dockerBuildkitIndex && idx < dockerBuildkitIndex + 10 && line.includes('run: |'))
        cy.wrap(runIndex).should('be.greaterThan', -1, 'run: | should appear after DOCKER_BUILDKIT')

        // Check for blank lines in the docker buildx build command (should not have blank lines between --load and -t)
        if (runIndex >= 0) {
          // Find the --load line and the -t line within the run block
          let loadIndex = -1
          let tagIndex = -1
          for (let i = runIndex; i < Math.min(runIndex + 20, lines.length); i++) {
            if (lines[i].includes('--load')) {
              loadIndex = i
            }
            if (lines[i].includes('-t ${{') || lines[i].includes('-t ${')) {
              tagIndex = i
              break
            }
          }
          if (loadIndex >= 0 && tagIndex >= 0 && tagIndex > loadIndex) {
            // Check for blank lines between --load and -t
            const linesBetween = lines.slice(loadIndex + 1, tagIndex)
            const blankLines = linesBetween.filter(line => line.trim() === '')
            cy.wrap(blankLines.length).should('eq', 0, `Found ${blankLines.length} blank line(s) between --load and -t in docker buildx build command`)
          }
        }

        // Validate YAML structure
        const validation = validateYaml(result)
        cy.wrap(validation.valid).should('be.true', `YAML validation failed: ${validation.error || 'unknown error'}`)
        cy.wrap(validation.parsed).should('have.property', 'name')
        cy.wrap(validation.parsed).should('have.property', 'on')
        cy.wrap(validation.parsed).should('have.property', 'jobs')

        // Check for actual error messages (not commands that contain "error")
        // Look for error patterns like "Error:" at start of line or in error messages
        const errorPattern = /^(Error|ERROR|error):|Error while|failed|Failed|FAILED/
        cy.wrap(result.split('\n').some(line => errorPattern.test(line.trim()))).should('be.false', 'Should not contain error messages')
        
        // Check that template blocks are processed (not left as literal [% ... %])
        cy.wrap(result).should('not.include', '[% if')
        cy.wrap(result).should('not.include', '[% else')
        cy.wrap(result).should('not.include', '[% endif')
        cy.wrap(result).should('not.include', '[% for')
        cy.wrap(result).should('not.include', '[% endfor')

        // Save output file for manual inspection (like Python scripts do)
        cy.writeFile('test/cypress/downloads/github-without-externalxar.yml', result)
        
        // Debug: log the lines around DOCKER_BUILDKIT
        const debugLines = lines.slice(Math.max(0, dockerBuildkitIndex - 2), Math.min(lines.length, dockerBuildkitIndex + 10))
        cy.log('Lines around DOCKER_BUILDKIT:', debugLines.join('\n'))
      })
    })

    it('POST /api/templates expands GitHub template with GITHUB_TOKEN', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: githubTemplate,
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'GITHUB_TOKEN'
                }
              }
            }
          },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        
        // Save output file for debugging even if test fails
        cy.writeFile('test/cypress/downloads/github-with-github-token.yml', res.body.result)
        
        cy.wrap(res.body.result).should('include', 'GITHUB_TOKEN')
        cy.wrap(res.body.result).should('include', 'secrets.GITHUB_TOKEN')

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
        cy.writeFile('test/cypress/downloads/github-with-github-token.yml', res.body.result)
      })
    })

    it('POST /api/templates expands GitHub template with custom token', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: githubTemplate,
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
        cy.writeFile('test/cypress/downloads/github-with-custom-token.yml', res.body.result)
        
        // Custom token should appear in the output
        cy.wrap(res.body.result).should('include', 'CUSTOM_TOKEN')
        cy.wrap(res.body.result).should('include', 'secrets.CUSTOM_TOKEN')

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
        cy.writeFile('test/cypress/downloads/github-with-custom-token.yml', res.body.result)
      })
    })

    it('generated GitHub Actions workflows validate against official JSON schema', () => {
      // Test all three scenarios: no externalXar, GITHUB_TOKEN, and custom token
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
          name: 'with GITHUB_TOKEN',
          params: {
            docker: {
              ports: { http: 8080 },
              externalXar: {
                'test.xar': {
                  url: 'https://example.com/test.xar',
                  token: 'GITHUB_TOKEN'
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
            template: githubTemplate,
            params: scenario.params,
            mode: 'text'
          }
        }).then(res => {
          cy.wrap(res).its('status').should('eq', 200)
          
          // Parse YAML to JSON for schema validation
          const workflowYaml = res.body.result
          const workflowJson = yaml.load(workflowYaml)
          
          // Validate against GitHub Actions workflow schema
          const schema = ajv7.getSchema('https://json.schemastore.org/github-workflow.json')
          if (!schema) {
            throw new Error('GitHub Actions workflow schema not loaded')
          }
          
          cy.validateJsonSchema(ajv7, schema.schema, workflowJson, `GitHub Actions workflow (${scenario.name})`)
        })
      })
    })
  })

  describe('TEI Publisher Docker Publish workflow template', () => {
    let publishTemplate

    before(() => {
      cy.readFile('profiles/ci/.github/workflows/tp-docker-publish.tpl.yml').then(template => {
        publishTemplate = template
      })
    })

    it('POST /api/templates expands tp-docker-publish template', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: publishTemplate,
          params: {},
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res).its('body').should('be.an', 'object')
        cy.wrap(res.body).should('have.property', 'result')

        const result = res.body.result

        // Validate YAML structure
        const validation = validateYaml(result)
        cy.wrap(validation.valid).should('be.true', `YAML validation failed: ${validation.error || 'unknown error'}`)
        cy.wrap(validation.parsed).should('have.property', 'name')
        cy.wrap(validation.parsed).should('have.property', 'on')
        cy.wrap(validation.parsed).should('have.property', 'jobs')

        // Check that template blocks are processed (not left as literal [% ... %])
        cy.wrap(result).should('not.include', '[% if')
        cy.wrap(result).should('not.include', '[% else')
        cy.wrap(result).should('not.include', '[% endif')
        cy.wrap(result).should('not.include', '[% for')
        cy.wrap(result).should('not.include', '[% endfor')

        // Save output file for manual inspection
        cy.writeFile('test/cypress/downloads/tp-docker-publish.yml', result)
      })
    })

    it('generated tp-docker-publish workflow validates against official JSON schema', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: publishTemplate,
          params: {},
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        
        // Parse YAML to JSON for schema validation
        const workflowYaml = res.body.result
        const workflowJson = yaml.load(workflowYaml)
        
        // Validate against GitHub Actions workflow schema
        const schema = ajv7.getSchema('https://json.schemastore.org/github-workflow.json')
        if (!schema) {
          throw new Error('GitHub Actions workflow schema not loaded')
        }
        
        cy.validateJsonSchema(ajv7, schema.schema, workflowJson, 'tp-docker-publish workflow')
      })
    })
  })
})
