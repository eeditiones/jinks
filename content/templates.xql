xquery version "3.1";

module namespace tmpl="http://e-editiones.org/xquery/templates";

(:~
 : Thrown if the parser reaches the end of the input stream
 : while trying to find the end* marker for a block.
 :)
declare variable $tmpl:ERROR_EOF := xs:QName("tmpl:error-eof");
declare variable $tmpl:ERROR_INCLUDE := xs:QName("tmpl:error-include");
declare variable $tmpl:ERROR_EXTENDS := xs:QName("tmpl:error-extends");

declare variable $tmpl:XML_MODE := map {
    "xml": true(),
    "block": map {
        "start": "&lt;t&gt;",
        "end": "&lt;/t&gt;/node()"
    },
    "enclose": map {
        "start": "{",
        "end": "}"
    },
    "text": function($text as xs:string) {
        replace($text, "\{", "{{") => replace("\}", "}}")
    }
};

declare variable $tmpl:TEXT_MODE := map {
    "xml": false(),
    "block": map {
        "start": "``[",
        "end": "]``"
    },
    "enclose": map {
        "start": "`{",
        "end": "}`"
    },
    "text": function($text as xs:string) {
        $text
    }
};

(:~
 : List of regular expressions used by the tokenizer
 :)
declare variable $tmpl:TOKEN_REGEX := [
    "\[%\s*(end\w+)\s*%\]",
    "\[%\s*(for)\s+(\$\w+)\s+in\s+(.+?)%\]",
    "\[%\s*(if)\s+(.+?)%\]",
    "\[%\s*(elif)\s+(.+?)%\]",
    "\[%\s*(else)\s*%\]",
    "\[%\s*(include)\s+(.+?)%\]",
    "\[%\s*(extends)\s+(.+?)%\]",
    "\[%\s*(block)\s+(.+?)%\]",
    "\[(\[)(.+?)\]\]"
];

(:~
 : Tokenize the input string. Returns a sequence of strings
 : and elements corresponding to the tokens found.
 :)
declare function tmpl:tokenize($input as xs:string) {
    let $regex := "(?:" || string-join($tmpl:TOKEN_REGEX, "|") || ")"
    (: First remove comments :)
    let $input := replace($input, "\[(#)(.*?)#\]", "", "is")
    let $analyzed := analyze-string($input, $regex, "is")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                let $type := $token/fn:group[1]
                return
                switch($type)
                    case "endfor" return
                        <endfor/>
                    case "endif" return
                        <endif/>
                    case "if" return
                        <if expr="{$token/fn:group[2] => normalize-space()}"/>
                    case "elif" return
                        <elif expr="{$token/fn:group[2] => normalize-space()}"/>
                    case "else" return
                        <else/>
                    case "for" return
                        <for var="{$token/fn:group[2] => normalize-space()}" expr="{$token/fn:group[3] => normalize-space()}"/>
                    case "include" return
                        <include target="{$token/fn:group[2] => normalize-space()}"/>
                    case "extends" return
                        <extends source="{$token/fn:group[2] => normalize-space()}"/>
                    case "block" return
                        <block name="{$token/fn:group[2] => normalize-space()}"/>
                    case "endblock" return
                        <endblock/>
                    case "[" return
                        <value expr="{$token/fn:group[2] => normalize-space()}"/>
                    default return
                        <error>{$token}</error>
            default return
                $token/string()
};

(:~
 : Find the end* expression matching the starting token (if, for ...) given by $type.
 : Respect nested expressions.
 :)
declare %private function tmpl:lookahead($tokens as item()*, $type as xs:string, $nesting as xs:integer) {
    if (empty($tokens)) then
        error($tmpl:ERROR_EOF, "Missing end" || $type)
    else
        let $next := head($tokens)
        return ($next,
            if ($next instance of element()) then
                if (local-name($next) = $type) then
                    tmpl:lookahead(tail($tokens), $type, $nesting + 1)
                else if (local-name($next) = "end" || $type) then
                    if ($nesting = 1) then
                        ()
                    else
                        tmpl:lookahead(tail($tokens), $type, $nesting - 1)
                else
                    tmpl:lookahead(tail($tokens), $type, $nesting)
            else
                tmpl:lookahead(tail($tokens), $type, $nesting)
        )
};

(:~
 : Processes the token stream and returns an XML fragment representing the abstract
 : syntax tree of the template.
 :
 : @param $tokens the input token stream
 : @param $resolver a function to resolve references to external resources (for include)
 :)
declare function tmpl:parse($tokens as item()*) {
    <ast>{tmpl:do-parse($tokens)}</ast>
};

declare %private function tmpl:do-parse($tokens as item()*) {
    if (empty($tokens)) then
        ()
    else
        let $next := head($tokens)
        return
            typeswitch ($next)
                case element(for) return
                    let $body := tmpl:lookahead(tail($tokens), "for", 1)
                    let $tail := subsequence(tail($tokens), count($body) + 1)
                    return (
                        <for var="{$next/@var}" expr="{$next/@expr}">
                        {
                            tmpl:do-parse($body)
                        }
                        </for>,
                        tmpl:do-parse($tail)
                    )
                case element(if) return
                    let $body := tmpl:lookahead(tail($tokens), "if", 1)
                    let $tail := subsequence(tail($tokens), count($body) + 1)
                    return (
                        <if expr="{$next/@expr}">
                        {
                            tmpl:do-parse($body)
                        }
                        </if>,
                        tmpl:do-parse($tail)
                    )
                case element(elif) return
                    let $body := tmpl:lookahead(tail($tokens), "if", 1)
                    return (
                        <elif expr="{$next/@expr}">
                        {
                            tmpl:do-parse($body)
                        }
                        </elif>
                    )
                case element(else) return
                    let $body := tmpl:lookahead(tail($tokens), "if", 1)
                    return (
                        <else>
                        {
                            tmpl:do-parse($body)
                        }
                        </else>
                    )
                case element(block) return
                    let $body := tmpl:lookahead(tail($tokens), "block", 1)
                    let $tail := subsequence(tail($tokens), count($body) + 1)
                    return (
                        <block name="{$next/@name}">
                        {
                            tmpl:do-parse($body)
                        }
                        </block>,
                        tmpl:do-parse($tail)
                    )
                case element(include) | element(extends) return
                    ($next, tmpl:do-parse(tail($tokens)))
                case element(endfor) | element(endif) | element(endblock) | element(comment) return
                    ()
                default return
                    ($next, tmpl:do-parse(tail($tokens)))
};

(:~
 : Transform the AST into executable XQuery code, using the given configuration
 : and parameters.
 :
 : Depending on the desired output format (XML/HTML or text), $config should be either:
 : $tmpl:XML_MODE or $tmpl:TEXT_MODE.
 :)
declare function tmpl:generate($config as map(*), $ast as element(ast), $params as map(*)) {
    let $body := $config?block?start || string-join(tmpl:emit($config, $ast)) || $config?block?end
    let $code := string-join((tmpl:vars($params), $body), "&#10;")
    let $blocks :=
        string-join(
            for $block in $ast//block
            let $blockContent := "``[" || serialize($block) || "]``"
            return
                ``["`{$block/@name}`": `{ $blockContent }`]``,
            ",&#10;"
        )
    return
        (: if template extends another, output call to tmpl:extends :)
        if ($ast//extends) then
            ``[
declare variable $local:blocks := map {
    `{$blocks}`
};

declare function local:content($_params as map(*), $_resolver as function(*)) {
    `{$code}`
};
            
tmpl:extends(`{$ast/extends/@source}`, local:content#2, $_params, $_resolver, 
    `{if ($config?xml) then 'false()' else 'true()'}`, $local:blocks)]``
        (: otherwise just output the code :)
        else
            $code
};

(:~
 : Recursively traverse AST nodes and generate XQuery code
 :)
declare %private function tmpl:emit($config as map(*), $nodes as item()*) {
    string-join(
        for $node in $nodes
        return
            typeswitch ($node)
                case element(if) return
                    tmpl:escape($config, $node,
                        "if (" || $node/@expr || ") then&#10;"
                        || $config?block?start
                        || tmpl:emit($config, $node/node())
                        || $config?block?end
                        || (if ($node/(else|elif)) then () else "&#10;else ()")
                    )
                case element(elif) return
                    $config?block?end ||
                    "else if (" || $node/@expr || ") then&#10;"
                    || $config?block?start
                    || tmpl:emit($config, $node/node())
                    || (if ($node/(else|elif)) then () else "&#10;else ()")
                case element(for) return
                    tmpl:escape($config, $node,
                        "for " || $node/@var || " in " || $node/@expr || " return&#10;"
                        || $config?block?start
                        || tmpl:emit($config, $node/node())
                        || $config?block?end
                    )
                case element(else) return
                    $config?block?end || "else&#10;" || $config?block?start 
                    || tmpl:emit($config, $node/node())
                case element(include) return
                    tmpl:escape($config, $node,
                        "tmpl:include(" || $node/@target || ", $_resolver, $_params, "
                        || (if ($config?xml) then "false()" else "true()")
                        || ")"
                    )
                case element(value) return
                    let $expr :=
                        if (matches($node/@expr, "^[^$][\w_-]+$")) then
                            "$" || $node/@expr
                        else
                            $node/@expr
                    return
                        tmpl:escape($config, $node, $expr)
                case element(block) return
                    ()
                case element() return
                    tmpl:emit($config, $node/node())
                default return
                    $config?text($node)
    )
};

(:~
 : Depending on the output mode (XML/HTML or text), some expressions may need
 : to be marked as enclosed expressions.
 :)
declare %private function tmpl:escape($config as map(*), $node as element(), $content as item()*) {
    let $preceding := $node/preceding-sibling::node()[not(matches(., "^[\s\n]+$"))][1]
    return
        if ($config?xml and empty($preceding) and $node/parent::*[not(self::ast)]) then
            $content
        else
            $config?enclose?start || $content || $config?enclose?end
};

(:~
 : Creates a let ... return prolog, mapping each key/value in $params
 : to a parameter named like the key.
 :)
declare %private function tmpl:vars($params as map(*)) {
    if (map:size($params) > 0) then
        map:for-each($params, function($key, $value) {
            ``[
                let $`{$key}` := $_params?`{$key}` ]``
        }) => string-join()
        || " return "
    else
        ()
};

(:~
 : Evaluate the passed in XQuery code.
 :)
declare function tmpl:eval($code as xs:string, $_params as map(*), $_resolver as function(*)?) {
    util:eval($code)
};

declare function tmpl:process($template as xs:string, $params as map(*), $plainText as xs:boolean?, 
    $resolver as function(*)?) {
    tmpl:process($template, $params, $plainText, $resolver, false())
};

(:~
 : Compile and execute the given template. Convenience method which combines
 : tokenize, parse, generate and eval.
 :)
declare function tmpl:process($template as xs:string, $params as map(*), $plainText as xs:boolean?, 
    $resolver as function(*)?, $debug as xs:boolean?) {
    let $ast := tmpl:tokenize($template) => tmpl:parse()
    let $mode := if ($plainText) then $tmpl:TEXT_MODE else $tmpl:XML_MODE
    let $code := tmpl:generate($mode, $ast, $params)
    let $result := tmpl:eval($code, $params, $resolver)
    return
        if ($debug) then
            map {
                "ast": $ast,
                "xquery": $code,
                "result": 
                    if (not($plainText)) then
                        serialize($result, map { "indent": true() })
                    else
                        $result
            }
        else
            $result
};

declare function tmpl:include($path as xs:string, $resolver as function(*)?, $params as map(*), 
    $plainText as xs:boolean?) {
    if (empty($resolver)) then
        error($tmpl:ERROR_INCLUDE, "Include is not available in this templating context")
    else
        let $template := $resolver($path)
        return
            if (exists($template)) then
                let $result := tmpl:process($template, $params, $plainText, $resolver, false())
                return
                    if ($result instance of map(*) and $result?error) then
                        error($tmpl:ERROR_INCLUDE, $result?error)
                    else
                        $result
            else
                error($tmpl:ERROR_INCLUDE, "Included template " || $path || " not found")
};

(:~
 : Helper function called at runtime: 
 : 
 : * load and parse the base template specified by $path
 : * call $contentFunc to set variable $content
 : * replace all named blocks in ast of base template with corresponding blocks from child
 : given in $blocks
 :)
declare function tmpl:extends($path as xs:string, $contentFunc as function(*), $params as map(*), 
    $resolver as function(*)?, $plainText as xs:boolean?, $blocks as map(*)) {
    if (empty($resolver)) then
        error($tmpl:ERROR_EXTENDS, "Extends is not available in this templating context")
    else
        let $template := $resolver($path)
        return
            if (exists($template)) then
                let $content := $contentFunc($params, $resolver)
                let $params := map:merge((
                    $params,
                    map {
                        "content": $content
                    }
                ))
                return
                    tmpl:process-blocks($template, $params, $plainText, $resolver, $blocks)
            else
                error($tmpl:ERROR_EXTENDS, "Extended template " || $path || " not found")
};

declare %private function tmpl:process-blocks($template as xs:string, $params as map(*), $plainText as xs:boolean?,
    $resolver as function(*), $blocks as map(*)) {
    (: parse the extended template :)
    let $ast := tmpl:tokenize($template) => tmpl:parse()
    (: replace blocks in template with corresponding blocks of child :)
    let $modifiedAst := tmpl:replace-blocks($ast, $blocks)
    let $mode := if ($plainText) then $tmpl:TEXT_MODE else $tmpl:XML_MODE
    let $code := tmpl:generate($mode, $modifiedAst, $params)
    return
        try {
            tmpl:eval($code, $params, $resolver)
        } catch * {
            error($tmpl:ERROR_EXTENDS, $err:description)
        }
};

declare %private function tmpl:replace-blocks($ast as node()*, $blocks as map(*)) {
    for $node in $ast
    return
        typeswitch($node)
            case element(block) return
                if (map:contains($blocks, $node/@name)) then
                    parse-xml($blocks($node/@name))/block/node()
                else
                    $node/node()
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    tmpl:replace-blocks($node/node(), $blocks)
                }
            default return
                $node
};