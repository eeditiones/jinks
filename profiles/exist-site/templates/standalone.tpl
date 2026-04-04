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
    <main id="main-content">
        [% block content %][% endblock %]
    </main>
</body>
</html>
