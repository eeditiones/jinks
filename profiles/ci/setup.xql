xquery version "3.1";

module namespace ci="https://e-editiones.org/app/tei-publisher/ci/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";

declare namespace generator="http://tei-publisher.com/library/generator";

(:~
 : Write CI configuration files based on the selected provider.
 : Default is GitHub Actions, GitLab CI is optional.
 :
 : @param $context the context map containing configuration
 :)
declare 
    %generator:write
function ci:setup($context as map(*)) {
    let $ciConfig := head(($context?ci, map { "provider": "github", "enabled": true() }))
    let $enabled := head(($ciConfig?enabled, true()))
    let $provider := head(($ciConfig?provider, "github"))
    
    return
        if (not($enabled)) then
            util:log("INFO", "ci: CI configuration disabled, skipping...")
        else
            let $_ := util:log("INFO", "ci: Generating CI configuration for provider: " || $provider)
            let $ciFiles :=
                if ($provider = "github") then
                    let $workflow := ci:generate-github-actions($context)
                    (: Generate dependabot.yml (GitHub-specific) :)
                    let $dependabot := ci:generate-dependabot($context)
                    (: Generate FUNDING.yml if conditions are met (GitHub-specific) :)
                    let $funding := ci:generate-funding($context)
                    (: Generate docker-publish.yml if conditions are met (GitHub-specific) :)
                    let $dockerPublish := ci:generate-docker-publish($context)
                    return
                        ($workflow, $dependabot, $funding, $dockerPublish)
                else if ($provider = "gitlab") then
                    ci:generate-gitlab-ci($context)
                else
                    util:log("WARN", "ci: Unknown CI provider: " || $provider || ", skipping CI configuration")
            
            return
                $ciFiles
};

(:~
 : Generate GitHub Actions workflow file
 :
 : @param $context the context map
 :)
declare %private function ci:generate-github-actions($context as map(*)) {
    (: Ensure .github/workflows directory exists :)
    let $_ := path:mkcol($context, ".github/workflows")
    let $targetPath := ".github/workflows/ci.yml"
    
    return
        cpy:copy-template($context, ".github/workflows/ci.tpl.yml", $targetPath)
};

(:~
 : Generate GitLab CI configuration file
 :
 : @param $context the context map
 :)
declare %private function ci:generate-gitlab-ci($context as map(*)) {
    let $targetPath := ".gitlab-ci.yml"
    
    return
        cpy:copy-template($context, ".gitlab-ci.tpl.yml", $targetPath)
};

(:~
 : Generate dependabot.yml file for GitHub Actions
 :
 : @param $context the context map
 :)
declare %private function ci:generate-dependabot($context as map(*)) {
    let $_ := path:mkcol($context, ".github")
    let $targetPath := ".github/dependabot.yml"
    
    return
        cpy:copy-resource($context, ".github/dependabot.yml", $targetPath)
};

(:~
 : Generate FUNDING.yml file if conditions are met:
 : - The qualified name (id) contains "https://e-editiones.org"
 :
 : @param $context the context map
 :)
declare %private function ci:generate-funding($context as map(*)) {
    let $id := head(($context?id, ""))
    let $hasEeditionesId := contains($id, "https://e-editiones.org")
    
    return
        if ($hasEeditionesId) then
            let $_ := path:mkcol($context, ".github")
            let $targetPath := ".github/FUNDING.yml"
            return
                cpy:copy-resource($context, ".github/FUNDING.yml", $targetPath)
        else
            ()
};

(:~
 : Generate docker-publish.yml workflow file if conditions are met:
 : - "docs" blueprint is selected
 : - pkg?abbrev == "tei-publisher"
 :
 : @param $context the context map
 :)
declare %private function ci:generate-docker-publish($context as map(*)) {
    let $abbrev := head(($context?pkg?abbrev, ""))
    let $profiles := $context?profiles?*
    let $hasDocs := "docs" = $profiles
    
    return
        if ($abbrev = "tei-publisher" and $hasDocs) then
            let $_ := path:mkcol($context, ".github/workflows")
            let $targetPath := ".github/workflows/docker-publish.yml"
            return
                cpy:copy-template($context, ".github/workflows/tp-docker-publish.tpl.yml", $targetPath)
        else
            ()
};
