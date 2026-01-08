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
            return
                if ($provider = "github") then
                    ci:generate-github-actions($context)
                else if ($provider = "gitlab") then
                    ci:generate-gitlab-ci($context)
                else
                    util:log("WARN", "ci: Unknown CI provider: " || $provider || ", skipping CI configuration")
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
