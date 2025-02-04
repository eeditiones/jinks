| Expression | Description |
| -------- | ------- |
| `[[ expr ]]` | Insert result of evaluating `expr` |
| `[% if expr %] … [% endif %]` | Conditional evaluation of block |
| `… [% elsif expr %] …` | *else if* block after *if* |
| `… [% else %] … [% endif %]` | *else* block after *if* or *else if* |
| `[% for $var in expr %] … [% endfor %]` | Loop `$var` over sequence returned by `expr` |
| `[% include expr %]` | Include a partial. `expr` should resolve to relative path. |
| `[% block name %]… [% endblock %]` | Defines a named block, optionally containing fallback content. |
| `[% template name %]… [% endtemplate %]` | Contains content to be appended to the block with the same name. |
| `[% import "uri" as "prefix" at "path" %]` | Import an XQuery module so its functions/variables can be used in template expressions. |
| `[# … #]` | Single or multi-line comment: content will be discarded |

`expr` must be a valid XPath expression.