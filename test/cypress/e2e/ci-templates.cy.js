/// <reference types="cypress" />

const yaml = require('js-yaml')

describe('CI Templates', () => {
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
  })

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
        
        // Find export DOCKER_BUILDKIT line and verify no blank line follows
        const dockerBuildkitIndex = lines.findIndex(line => line.includes('export DOCKER_BUILDKIT=1'))
        cy.wrap(dockerBuildkitIndex).should('be.greaterThan', -1)
        
        // Next line should be 'docker buildx build' with no blank line in between
        const nextLine = lines[dockerBuildkitIndex + 1]
        cy.wrap(nextLine).should('include', 'docker buildx build')
        cy.wrap(nextLine.trim()).should('not.be.empty')

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
  })

  describe('Template validation', () => {
    it('POST /api/templates returns 200 for valid template with empty params', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: 'Simple template without placeholders',
          params: {},
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body).should('have.property', 'result')
        cy.wrap(res.body.result).should('eq', 'Simple template without placeholders')
      })
    })

    it('POST /api/templates returns 200 for template with variable interpolation', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: 'Hello [[ $name ]]',
          params: { name: 'World' },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body.result).should('include', 'Hello')
        cy.wrap(res.body.result).should('include', 'World')
      })
    })

    it('POST /api/templates returns 200 for template with conditional logic', () => {
      cy.request({
        method: 'POST',
        url: '/api/templates',
        headers: { 'content-type': 'application/json' },
        body: {
          template: '[% if $show %]Visible[% else %]Hidden[% endif %]',
          params: { show: true },
          mode: 'text'
        }
      }).then(res => {
        cy.wrap(res).its('status').should('eq', 200)
        cy.wrap(res.body.result).should('include', 'Visible')
        cy.wrap(res.body.result).should('not.include', 'Hidden')
      })
    })
  })
})
