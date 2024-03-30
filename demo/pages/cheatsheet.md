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