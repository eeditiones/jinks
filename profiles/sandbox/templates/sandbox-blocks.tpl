<template>
    [% template scripts %]
    [% if $context?features?sandbox?enabled %]
    <script type="module" src="[[ $contextPath ]]/resources/scripts/playground.min.js"></script>
    <script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/jinn-codemirror@1.18.2/dist/jinn-codemirror-bundle.js"></script>
    <script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/fore@2.9.0/dist/fore.js"></script>
    [% endif %]
    [% endtemplate %]

    [% template styles %]
    [% if $context?features?sandbox?enabled %]
    <link rel="stylesheet" href="[[ $contextPath ]]/resources/css/playground.css"/>
    [% endif %]
    [% endtemplate %]

    [% template menu 50 %]
    [% if $context?features?sandbox?enabled %]
    <li><a href="[[ $contextPath ]]/sandbox">Sandbox</a></li>
    [% endif %]
    [% endtemplate %]
</template>
