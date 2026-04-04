<html lang="en">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>[% block title %]eXist-db[% endblock %]</title>
    [% for $path in $styles?* %]
    [% if matches($path, "(?:^https?://|^/).*$") %]
    <link rel="stylesheet" href="[[ $path ]]"/>
    [% else %]
    <link rel="stylesheet" href="[[ $context-path ]]/[[ $path ]]"/>
    [% endif %]
    [% endfor %]
    [% block head %][% endblock %]
</head>
<body>
    <a href="#main-content" class="skip-link">Skip to content</a>

    <header class="site-header">
        <nav class="site-nav" aria-label="Main navigation">
            <a href="/" class="site-logo">
                <img src="[[ $context-path ]]/[[ $site?logo ]]" alt="[[ $site?name ]]" height="32"/>
            </a>

            <ul class="site-menu">
                [% for $app in nav:apps($nav?items, $context-path)?* %]
                [% if $app?active %]
                <li><a href="[[ $app?url ]]" class="active">[[ $app?title ]]</a></li>
                [% else %]
                <li><a href="[[ $app?url ]]">[[ $app?title ]]</a></li>
                [% endif %]
                [% endfor %]
            </ul>

            <form class="site-search" action="[[ $context-path ]]/search" method="get">
                <label for="site-search-input" class="visually-hidden">Search</label>
                <input type="search" id="site-search-input" name="q"
                       placeholder="Search..."
                       aria-label="Sitewide search"/>
            </form>

            <div class="site-user">
                [% if site-config:current-user() != 'guest' %]
                    <span>[[ site-config:current-user() ]]</span>
                    <a href="[[ $context-path ]]/logout?redirect=[[ encode-for-uri(request:get-uri()) ]]">Logout</a>
                [% else %]
                    <a href="[[ $context-path ]]/login">Login</a>
                [% endif %]
            </div>
        </nav>
    </header>

    <main id="main-content">
        [% block content %][% endblock %]
    </main>

    <footer class="site-footer">
        <p>Copyright 2001-2026 The eXist-db Authors.
           <a href="https://github.com/eXist-db/exist">Source</a> |
           <a href="https://exist-db.org">exist-db.org</a>
        </p>
    </footer>

</body>
</html>
