# Templating Module for Plain Text

Because eXist's HTML templating is only usable for HTML, the generator includes its own templating module, which is able to process both, XML/HTML and plain text files. The module was inspired by other templating languages like *nunjucks* or *jsx*, but uses the full power of XPath for expressions. It was also designed to be backwards-compatible with the simpler templating syntax TEI Publisher uses within ODD, further extending the possibilities available within the `pb:template` element in ODD.

Instead of being entirely based on regular expressions, the templating module implements a parser generating an abstract syntax tree (AST) in XML. The AST is then compiled into XQuery code, which - when executed - produces the final output.

| Expression | Description |
| -------- | ------- |
| `[[ expr ]]` | Insert result of evaluating `expr` |
| `[% if expr %] … [% endif %]` | Conditional evaluation of block |
| `… [% elsif expr %] …` | *else if* block after *if* |
| `… [% else %] … [% endif %]` | *else* block after *if* or *else if* |
| `[% for $var in expr %] … [% endfor %]` | Loop `$var` over sequence returned by `expr` |
| `[% include expr %]` | Include a partial. `expr` should resolve to relative path. |
| `[% extends expr %]` | Extend a base template: contents of child template passed to base template in variable `$content`. Named blocks in child overwrite blocks in base. |
| `[% block name %]` | Defines a named block or overwrites corresponding block in base template. |
| `[# … #]` | Single or multi-line comment: content will be discarded |

`expr` must be a valid XPath expression.