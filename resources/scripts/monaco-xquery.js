// XQuery language definition for Monaco Editor
export const xqueryLanguage = {
    defaultToken: '',
    tokenPostfix: '.xq',

    keywords: [
        'and', 'as', 'ascending', 'at', 'attribute', 'base-uri', 'boundary-space',
        'case', 'cast', 'castable', 'comment', 'construction', 'copy-namespaces',
        'declare', 'default', 'descending', 'div', 'document', 'element', 'else',
        'empty', 'encoding', 'eq', 'every', 'except', 'external', 'following',
        'for', 'function', 'ge', 'gt', 'idiv', 'if', 'import', 'in', 'inherit',
        'instance', 'intersect', 'is', 'item', 'le', 'let', 'lt', 'mod', 'module',
        'namespace', 'ne', 'node', 'of', 'option', 'or', 'order', 'ordered',
        'parent', 'preceding', 'processing-instruction', 'return', 'satisfies',
        'schema', 'self', 'some', 'stable', 'strict', 'strip', 'text', 'then',
        'to', 'treat', 'typeswitch', 'union', 'unordered', 'validate', 'variable',
        'version', 'where', 'xquery'
    ],

    operators: [
        '=', '>', '<', '!', '?', ':', '==', '<=', '>=', '!=',
        '&&', '||', '+', '-', '*', '/', '\\', '%', '|', '&', '^', '!',
        '~', '+=', '-=', '*=', '/=', '%=', '^=', '|=', '&=',
        '>>=', '>>>=', '<<=', '||='
    ],

    symbols: /[=><!~?:&|+\-*\/\^%]+/,
    escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

    tokenizer: {
        root: [
            [/[a-zA-Z_$][\w$]*/, { cases: { '@keywords': 'keyword', '@default': 'identifier' }}],
            { include: '@whitespace' },
            [/[{}()\[\]]/, '@brackets'],
            [/[<>](?!@symbols)/, '@brackets'],
            [/@symbols/, { cases: { '@operators': 'operator', '@default': '' }}],
            [/\d*\.\d+([eE][\-+]?\d+)?/, 'number.float'],
            [/\d+/, 'number'],
            [/"([^"\\]|\\.)*$/, 'string.invalid'],
            [/'([^'\\]|\\.)*$/, 'string.invalid'],
            [/"/, 'string', '@string_double'],
            [/'/, 'string', '@string_single'],
            [/\(:/, 'comment', '@comment'],
        ],

        comment: [
            [/[^(:)]+/, 'comment'],
            [/\(:/, 'comment', '@push'],
            [/:\)/, 'comment', '@pop'],
            [/[(:)]/, 'comment']
        ],

        string_double: [
            [/[^\\"]+/, 'string'],
            [/@escapes/, 'string.escape'],
            [/\\./, 'string.escape.invalid'],
            [/"/, 'string', '@pop']
        ],

        string_single: [
            [/[^\\']+/, 'string'],
            [/@escapes/, 'string.escape'],
            [/\\./, 'string.escape.invalid'],
            [/'/, 'string', '@pop']
        ],

        whitespace: [
            [/[ \t\r\n]+/, 'white'],
            [/\(:/, 'comment', '@comment']
        ],
    }
};

export function registerXQuery(monaco) {
    // Register language
    monaco.languages.register({ id: 'xquery' });
    
    // Register syntax highlighting
    monaco.languages.setMonarchTokensProvider('xquery', xqueryLanguage);
} 