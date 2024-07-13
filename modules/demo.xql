xquery version "3.1";

module namespace demo="https://tei-publisher.com/jinks/xquery/demo";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";

declare function demo:sysinfo($title as xs:string) {
    <ul>
        <li>Application title: {$title}</li>
        <li>Application root: {$config:app-root}</li>
        <li>Context path: {$config:context-path}</li>
    </ul>
};

declare function demo:sysinfo2() {
    map {
        "version": system:get-version(),
        "build": system:get-build()
    }
};