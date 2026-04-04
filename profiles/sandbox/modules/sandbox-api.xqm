xquery version "3.1";

(:~
 : API module for the Sandbox XQuery playground.
 : Provides XQuery evaluation, notebook rendering, content listing, and sharing.
 :)
module namespace sbox="http://exist-db.org/apps/sandbox/api";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace md="http://exist-db.org/xquery/markdown";

declare variable $sbox:APP_ROOT := "/db/apps/sandbox";

(:~
 : Execute an XQuery expression with optional context chain from preceding cells.
 : The context chain builds a let-clause preamble so variables from earlier cells
 : are available in the current cell.
 :
 : @param $request the roaster request map
 : @return map with result, count, elapsed, type — or error details
 :)
declare function sbox:eval($request as map(*)) {
    let $body := $request?body
    let $query := $body?query
    let $context-chain := $body?context  (: array of preceding cell queries :)
    let $timeout := ($body?timeout, 5000)[1]
    (: Serialization can be a string ("json") or a map ({"method":"json","indent":"yes"}) :)
    let $ser-opts :=
        if ($body?serialization instance of map(*)) then
            (: Pass through as-is — client should send spec-conformant values.
               Only convert indent/omit-xml-declaration which are xs:boolean in the spec
               but arrive as strings from JSON. :)
            let $raw := $body?serialization
            let $boolean-params := ("indent", "omit-xml-declaration", "standalone",
                "escape-uri-attributes", "include-content-type", "undeclare-prefixes")
            return map:merge(
                for $key in map:keys($raw)
                let $val := $raw($key)
                return map:entry($key,
                    if ($key = $boolean-params) then
                        string($val) = ("yes", "true", "1")
                    else
                        $val
                )
            )
        else
            map { "method": ($body?serialization, "adaptive")[1] }
    let $base-uri := $body?baseUri  (: optional: book content directory for resolving relative paths :)

    (: Build the let-chain from preceding cells :)
    let $preamble :=
        if (exists($context-chain)) then
            for $cell at $pos in $context-chain?*
            return
                "let $cell" || $pos || " := (" || $cell?query || ")"
        else
            ()

    (: If a baseUri is provided, inject a $data-collection variable
       that points to the book's data directory, so queries can use it.
       Also rewrite relative collection("...") and doc("...") paths
       to absolute paths. :)
    let $resolved-query :=
        if ($base-uri) then
            let $q := $query
            (: Rewrite collection("relative") but not collection("/absolute") :)
            let $q := replace($q, 'collection\("([^"/])', 'collection("' || $base-uri || '/$1')
            let $q := replace($q, "collection\('([^'/])", "collection('" || $base-uri || "/$1")
            let $q := replace($q, 'doc\("([^"/])', 'doc("' || $base-uri || '/$1')
            let $q := replace($q, "doc\('([^'/])", "doc('" || $base-uri || "/$1")
            return $q
        else
            $query

    let $full-query :=
        if (exists($preamble)) then
            string-join($preamble, "&#10;") || "&#10;return&#10;" || $resolved-query
        else
            $resolved-query

    let $start := util:system-time()
    return
        try {
            let $result := util:eval($full-query, false(), (), false())
            let $elapsed := util:system-time() - $start
            return map {
                "result": serialize($result, $ser-opts),
                "count": count($result),
                "elapsed": string($elapsed),
                "type": ($ser-opts?method, "adaptive")[1]
            }
        } catch * {
            map {
                "error": $err:description,
                "code": string($err:code),
                "line": $err:line-number,
                "column": $err:column-number
            }
        }
};

(:~
 : Compile-check XQuery code and return lint results.
 : Compatible with jinn-codemirror's built-in linter protocol:
 :   POST body: code=<xquery> (form-urlencoded)
 :   Response: { "status": "ok" } or { "status": "fail", "message": "...", "line": N, "column": N }
 :)
declare function sbox:lint($request as map(*)) {
    let $code := $request?body?code
    return
        if (not($code) or $code = "") then
            map { "status": "ok" }
        else
            let $result := util:compile($code)
            return
                (: util:compile returns a string; empty string or "compiled" means ok :)
                if (not($result) or $result = "" or starts-with($result, "compiled")) then
                    map { "status": "ok" }
                else
                    let $msg := replace($result, "^error found while executing expression:\s*", "")
                    let $msg := replace($msg, "^org\.exist\.xquery\.\w+:\s*", "")
                    let $msg := replace($msg, "\n$", "")
                    let $loc := analyze-string($result, "\[at line (\d+), column (\d+)\]")
                    let $line := if ($loc//fn:group[@nr="1"]) then xs:integer($loc//fn:group[@nr="1"]) else 1
                    let $column := if ($loc//fn:group[@nr="2"]) then xs:integer($loc//fn:group[@nr="2"]) else 1
                    (: Keep the [at line N, column N] suffix for now to help verify location :)
                    return map {
                        "status": "fail",
                        "message": $msg,
                        "line": $line,
                        "column": $column
                    }
};

(:~
 : Render a markdown file as an interactive notebook.
 : XQuery fenced code blocks become executable Fore-powered cells.
 :
 : @param $request the roaster request map
 : @return HTML notebook page
 :)
declare function sbox:notebook($request as map(*)) {
    let $path := $request?parameters?path
    let $content-path := $sbox:APP_ROOT || "/content/" || $path
    let $source := sbox:load-resource($content-path)
    let $_ :=
        if (empty($source)) then
            error($errors:NOT_FOUND, "Content file not found: " || $path)
        else ()

    (: Determine directory and check for book.json with context field :)
    let $dir :=
        if (contains($path, "/")) then
            substring-before($path, "/")
        else ()
    let $book-json-path := if ($dir) then $sbox:APP_ROOT || "/content/" || $dir || "/book.json" else ()
    let $base-uri :=
        if ($book-json-path and util:binary-doc-available($book-json-path)) then
            let $book := parse-json(util:binary-to-string(util:binary-doc($book-json-path)))
            return
                if ($book?context) then
                    $sbox:APP_ROOT || "/content/" || $dir
                else ()
        else ()

    (: Parse markdown with exist-markdown (flexmark) :)
    let $doc := md:parse($source)

    (: Extract title from first heading :)
    let $title :=
        let $heading := ($doc//md:heading)[1]
        return
            if ($heading) then
                string($heading)
            else
                replace($path, "\.md$", "")

    (: Assign cell IDs to each xquery fenced-code block :)
    let $xquery-blocks := $doc//md:fenced-code[starts-with(@language, "xquery")]
    let $total-cells := count($xquery-blocks)

    (: Transform: prose → HTML, xquery blocks → Fore cells :)
    let $content :=
        for $node in $doc/md:document/*
        return
            if ($node/self::md:fenced-code[starts-with(@language, "xquery")]) then
                let $cell-id := count($node/preceding::md:fenced-code[starts-with(@language, "xquery")]) + 1
                let $options := sbox:parse-cell-options(string($node/@language))
                return sbox:render-cell($cell-id, string($node), $total-cells, $options)
            else if ($node/self::md:fenced-code) then
                (: Non-XQuery code blocks: syntax-highlighted but not executable :)
                <pre><code class="language-{$node/@language}">{string($node)}</code></pre>
            else
                md:to-html($node)

    let $ctx := request:get-context-path() || "/apps/sandbox"
    return
        sbox:page-wrapper($title, $ctx,
            <div class="notebook" data-path="{$path}" data-total-cells="{$total-cells}"
                 data-base-uri="{if ($base-uri) then $base-uri else ''}">
                <div class="notebook-header">
                    <h2>{$title}</h2>
                    <div class="notebook-actions">
                        <button class="run-all-btn" onclick="playground.runAllCells()">Run All ▶▶</button>
                        <button class="share-btn" onclick="playground.shareNotebook()">Share</button>
                    </div>
                </div>
                <div class="notebook-content">
                    {$content}
                </div>
            </div>
        )
};

(:~
 : Render the standalone sandbox editor page.
 :
 : @param $request the roaster request map
 : @return HTML sandbox page
 :)
declare function sbox:sandbox($request as map(*)) {
    let $ctx := request:get-context-path() || "/apps/sandbox"
    return
        sbox:page-wrapper("Sandbox", $ctx,
            <div class="sandbox">
                <div class="sandbox-layout">
                    <div class="slots-sidebar">
                        <h3>Slots</h3>
                        {
                            for $i in 1 to 10
                            return
                                <button class="slot-btn" data-slot="{$i}"
                                    onclick="playground.loadSlot({$i})">Slot {$i}</button>
                        }
                    </div>

                    <div class="editor-panel">
                        <div class="toolbar">
                            <select id="sandbox-serialization" class="serialization-select">
                                <option value="adaptive" selected="selected">Adaptive</option>
                                <option value="xml">XML</option>
                                <option value="json">JSON</option>
                            </select>
                        </div>

                        <div class="main-editor">
                            <jinn-codemirror mode="xquery" code=""></jinn-codemirror>
                        </div>

                        <div class="actions">
                            <button onclick="playground.runSandbox()">Send</button>
                            <button onclick="playground.clearSandbox()">Clear</button>
                            <button onclick="playground.saveSlot()">Save to Slot</button>
                        </div>
                    </div>

                    <div class="result-panel">
                        <div class="result-header" style="display:none">
                            <span class="result-meta"></span>
                        </div>
                        <pre class="result-output" style="display:none"></pre>
                        <div class="error-panel" style="display:none"></div>
                    </div>
                </div>
            </div>
        )
};

(:~
 : Render the landing page: books (subdirectories with book.json) and standalone notebooks.
 :)
declare function sbox:landing($request as map(*)) {
    let $ctx := request:get-context-path() || "/apps/sandbox"
    let $content-col := $sbox:APP_ROOT || "/content"

    (: Books: subdirectories with a book.json :)
    let $books :=
        for $dir in xmldb:get-child-collections($content-col)
        let $book-path := $content-col || "/" || $dir || "/book.json"
        where util:binary-doc-available($book-path)
        let $book := parse-json(util:binary-to-string(util:binary-doc($book-path)))
        order by $book?title
        return map:merge(($book, map { "dir": $dir }))

    (: Standalone notebooks: .md files in root content dir :)
    let $notebooks :=
        for $resource in xmldb:get-child-resources($content-col)
        where ends-with($resource, ".md")
        let $source := sbox:load-resource($content-col || "/" || $resource)
        let $doc := md:parse($source)
        let $title :=
            let $heading := ($doc//md:heading)[1]
            return if ($heading) then string($heading)
            else replace($resource, "\.md$", "")
        order by $title
        return map { "path": $resource, "title": $title }

    return
        sbox:page-wrapper("Sandbox", $ctx,
            <div class="landing">
                <div class="landing-hero">
                    <h2>XQuery Playground</h2>
                    <p>An interactive environment for writing, running, and sharing XQuery — powered by eXist-db.</p>
                    <div class="landing-actions">
                        <a href="{$ctx}/api/sandbox" class="landing-btn landing-btn-primary">Open Sandbox</a>
                    </div>
                </div>
                {
                    if (exists($books)) then
                        <section class="landing-notebooks">
                            <h3>Books</h3>
                            <p>Multi-chapter interactive tutorials with runnable XQuery examples.</p>
                            <ul class="content-list">
                            {
                                for $book in $books
                                return
                                    <li>
                                        <a href="{$ctx}/api/book/{$book?dir}">
                                            {$book?title}
                                            <span class="file-path">{string-join($book?authors?*, ", ")}
                                            {if ($book?difficulty) then " · " || $book?difficulty else ()}</span>
                                        </a>
                                    </li>
                            }
                            </ul>
                        </section>
                    else ()
                }
                {
                    if (exists($notebooks)) then
                        <section class="landing-notebooks">
                            <h3>Notebooks</h3>
                            <p>Standalone interactive documents.</p>
                            <ul class="content-list">
                            {
                                for $nb in $notebooks
                                return
                                    <li>
                                        <a href="{$ctx}/api/notebook/{$nb?path}">
                                            {$nb?title}
                                            <span class="file-path">{$nb?path}</span>
                                        </a>
                                    </li>
                            }
                            </ul>
                        </section>
                    else ()
                }
                <section class="landing-about">
                    <h3>Features</h3>
                    <ul class="feature-list">
                        <li><strong>Notebook mode</strong> — Markdown documents with executable XQuery cells, like Jupyter for XQuery</li>
                        <li><strong>Sandbox mode</strong> — A classic single-editor environment with 10 save slots</li>
                        <li><strong>Cell chaining</strong> — Pass results from earlier cells as context to later ones</li>
                        <li><strong>Multiple serializations</strong> — View results as adaptive, XML, or JSON</li>
                        <li><strong>Sharing</strong> — Save and share notebook states via short URLs</li>
                        <li><strong>Code formatting</strong> — Prettier-powered XQuery formatting</li>
                    </ul>
                </section>
            </div>
        )
};

(:~
 : Render a book table-of-contents page.
 :)
declare function sbox:book($request as map(*)) {
    let $ctx := request:get-context-path() || "/apps/sandbox"
    let $dir := $request?parameters?path
    let $book-path := $sbox:APP_ROOT || "/content/" || $dir || "/book.json"
    let $book :=
        if (util:binary-doc-available($book-path)) then
            parse-json(util:binary-to-string(util:binary-doc($book-path)))
        else
            error($errors:NOT_FOUND, "Book not found: " || $dir)
    return
        sbox:page-wrapper($book?title, $ctx,
            <div class="book-toc">
                <h2>{$book?title}</h2>
                <p class="book-meta">
                    {string-join($book?authors?*, ", ")}
                    {if ($book?difficulty) then <span class="badge">{$book?difficulty}</span> else ()}
                </p>
                {if ($book?description) then <p>{$book?description}</p> else ()}
                {if ($book?license) then <p class="book-license">{$book?license}</p> else ()}
                <ol class="chapter-list">
                {
                    for $ch in $book?chapters?*
                    return
                        <li>
                            <a href="{$ctx}/api/notebook/{$dir}/{$ch?file}">{$ch?title}</a>
                        </li>
                }
                </ol>
            </div>
        )
};

(:~
 : List available content: books and standalone notebooks (JSON API).
 :)
declare function sbox:list($request as map(*)) {
    let $content-col := $sbox:APP_ROOT || "/content"
    return
        if (xmldb:collection-available($content-col)) then
            array {
                (: Books :)
                for $dir in xmldb:get-child-collections($content-col)
                let $book-path := $content-col || "/" || $dir || "/book.json"
                where util:binary-doc-available($book-path)
                let $book := parse-json(util:binary-to-string(util:binary-doc($book-path)))
                order by $book?title
                return map {
                    "type": "book",
                    "path": $dir,
                    "title": $book?title,
                    "authors": $book?authors,
                    "description": $book?description,
                    "difficulty": $book?difficulty,
                    "chapters": $book?chapters
                },
                (: Standalone notebooks :)
                for $resource in xmldb:get-child-resources($content-col)
                where ends-with($resource, ".md")
                let $source := sbox:load-resource($content-col || "/" || $resource)
                let $doc := md:parse($source)
                let $title :=
                    let $heading := ($doc//md:heading)[1]
                    return if ($heading) then string($heading)
                    else replace($resource, "\.md$", "")
                order by $title
                return map {
                    "type": "notebook",
                    "path": $resource,
                    "title": $title
                }
            }
        else
            array {}
};

(:~
 : Save notebook state and return a share ID and URL.
 :
 : @param $request the roaster request map
 : @return map with id and url
 :)
declare function sbox:share($request as map(*)) {
    let $state := $request?body
    let $id := util:uuid()
    let $shares-col := $sbox:APP_ROOT || "/shares"
    let $_ :=
        if (not(xmldb:collection-available($shares-col))) then
            xmldb:create-collection($sbox:APP_ROOT, "shares")
        else
            ()
    let $_ := xmldb:store($shares-col,
        $id || ".json",
        serialize($state, map { "method": "json" }),
        "application/json")
    return map {
        "id": $id,
        "url": request:get-scheme() || "://" || request:get-server-name() ||
               ":" || request:get-server-port() ||
               "/exist/apps/sandbox/share/" || $id
    }
};

(:~
 : Load a previously shared notebook state.
 :
 : @param $request the roaster request map
 : @return saved notebook state as JSON
 :)
declare function sbox:load-share($request as map(*)) {
    let $id := $request?parameters?id
    let $path := $sbox:APP_ROOT || "/shares/" || $id || ".json"
    let $content := sbox:load-resource($path)
    return
        if ($content) then
            parse-json($content)
        else
            error($errors:NOT_FOUND, "Share not found: " || $id)
};

(: ==================== Private helpers ==================== :)

(:~
 : Parse Pandoc-style attributes from a fenced code block info string.
 : "xquery {method=json indent=yes}" → map { "method": "json", "indent": "yes" }
 :)
declare %private function sbox:parse-cell-options($language as xs:string) as map(*) {
    let $attr-match := analyze-string($language, "\{([^}]*)\}")
    return
        if ($attr-match//fn:group[@nr="1"]) then
            let $attr-str := string($attr-match//fn:group[@nr="1"])
            let $pairs := analyze-string($attr-str, '(\S+?)=("[^"]*"|''[^'']*''|\S+)')
            return map:merge(
                for $match in $pairs//fn:match
                let $key := string($match/fn:group[@nr="1"])
                let $val := string($match/fn:group[@nr="2"])
                (: Strip surrounding quotes if present :)
                let $val := replace($val, '^["'']|["'']$', '')
                return map:entry($key, $val)
            )
        else
            map {}
};

(:~
 : Render an XQuery cell with optional serialization attributes.
 :)
declare %private function sbox:render-cell(
    $cell-id as xs:integer,
    $query as xs:string,
    $total-cells as xs:integer,
    $options as map(*)
) {
    let $method := ($options?method, "adaptive")[1]
    let $has-options := map:size($options) > 0
    return
    <div class="cell" id="cell-{$cell-id}"
        data-method="{$method}"
        data-indent="{($options?indent, '')[1]}"
        data-item-separator="{($options?item-separator, '')[1]}"
        data-omit-xml-declaration="{($options?omit-xml-declaration, '')[1]}">
        <div class="cell-header">
            <span class="cell-number">In [{$cell-id}]:</span>
            {
                if ($cell-id > 1) then
                    <label class="cell-depends">
                        <input type="checkbox" class="use-context"/>
                        {" Use previous cells as context"}
                    </label>
                else
                    ()
            }
        </div>

        <div class="query-editor">
            <jinn-codemirror mode="xquery" code="{$query}"
                linter="{request:get-context-path()}/apps/sandbox/api/lint"></jinn-codemirror>
            {
                if ($has-options) then
                    <span class="cell-options-badge">{
                        string-join(
                            for $key in map:keys($options)
                            return $key || "=" || $options($key),
                            " "
                        )
                    }</span>
                else ()
            }
        </div>

        <div class="cell-actions">
            <button class="run-btn" onclick="playground.runCell({$cell-id})">Run ▶</button>
            <button class="reset-btn" onclick="playground.resetCell({$cell-id})">Reset ↺</button>

            <select class="serialization-select">
                <option value="adaptive">{if ($method = "adaptive") then attribute selected {"selected"} else ()}{if ($method = "adaptive" and $has-options) then "Adaptive (default)" else "Adaptive"}</option>
                <option value="xml">{if ($method = "xml") then attribute selected {"selected"} else ()}{if ($method = "xml" and $has-options) then "XML (default)" else "XML"}</option>
                <option value="json">{if ($method = "json") then attribute selected {"selected"} else ()}{if ($method = "json" and $has-options) then "JSON (default)" else "JSON"}</option>
                <option value="text">{if ($method = "text") then attribute selected {"selected"} else ()}{if ($method = "text" and $has-options) then "Text (default)" else "Text"}</option>
            </select>

            <label class="indent-toggle" title="Indent output">
                <input type="checkbox" class="indent-check"
                    checked="{if ($options?indent = 'yes') then 'checked' else ''}"/>
                {" Indent"}
            </label>

            <span class="cell-cursor-pos">Line 1, Col 1</span>
        </div>

        <div class="cell-result">
            <div class="result-header" style="display:none">
                Out [{$cell-id}]:
                <span class="result-meta"></span>
            </div>
            <pre class="result-output" style="display:none"></pre>
            <div class="error-panel" style="display:none"></div>
        </div>
    </div>
};

(:~
 : Process an HTML template with the given context.
 :)
(:~
 : Wrap page content in the shared HTML shell (header, nav, footer).
 :)
declare function sbox:page-wrapper($title as xs:string, $ctx as xs:string, $content as node()*) {
    <html lang="en">
        <head>
            <meta charset="UTF-8"/>
            <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
            <title>{$title} — Sandbox</title>
            <link rel="stylesheet" href="{$ctx}/resources/css/playground.css"/>
            <link rel="stylesheet" href="{$ctx}/resources/css/admin.css"/>
            <script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/jinn-codemirror@1.18.2/dist/jinn-codemirror-bundle.js"></script>
            <script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/fore@2.9.0/dist/fore.js"></script>
        </head>
        <body>
            <header class="playground-header">
                <h1><a href="{$ctx}/">Sandbox</a></h1>
                <nav>
                    <a href="{$ctx}/">Home</a>
                    <a href="{$ctx}/api/sandbox">Sandbox</a>
                    {
                        let $user := request:get-attribute("org.exist.login.user")
                        let $is-real-user := $user and not($user = ("guest", "nobody"))
                        let $groups := (sm:id()//sm:group/string(), sm:id()//sm:effective/sm:group/string())
                        return (
                            if ($groups = ("sandbox-manager", "dba")) then
                                <a href="{$ctx}/api/admin">Admin</a>
                            else (),
                            if ($is-real-user) then
                                <a href="{$ctx}/logout?logout=true">Logout ({$user})</a>
                            else
                                <a href="{$ctx}/login">Login</a>
                        )
                    }
                </nav>
            </header>
            <main>{$content}</main>
            <footer class="playground-footer">
                <p>Powered by <a href="https://exist-db.org">eXist-db</a></p>
            </footer>
            <script type="module" src="{$ctx}/resources/scripts/playground.min.js"></script>
            <script type="module" src="{$ctx}/resources/js/admin.js"></script>
        </body>
    </html>
};

declare function sbox:load-resource($path as xs:string) as xs:string? {
    if (util:binary-doc-available($path)) then
        util:binary-to-string(util:binary-doc($path))
    else if (doc-available($path)) then
        serialize(doc($path))
    else
        ()
};

declare %private function sbox:render-template($template-path as xs:string, $context as map(*)) {
    let $template := sbox:load-resource($sbox:APP_ROOT || "/" || $template-path)
    return
        tmpl:process($template, $context, map {
            "plainText": false(),
            "resolver": function($relPath as xs:string) {
                let $path := $sbox:APP_ROOT || "/templates/" || $relPath
                let $content := sbox:load-resource($path)
                return
                    if ($content) then
                        map {
                            "path": $path,
                            "content": $content
                        }
                    else
                        ()
            }
        })
};
