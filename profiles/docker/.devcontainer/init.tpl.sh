#!/usr/bin/env sh
[% if $docker?features?nodejs and $docker?features?xst %]
echo "Installing xst..."
npm install -g @existdb/xst
[% endif %]

sleep 10
cd $(dirname "$0")/..
ant
for XAR in build/*.xar; do
    echo Installing $XAR
    curl --upload-file $XAR -u 'admin:' http://localhost:8080/exist/rest/db/system/repo/init.xar
    curl -u 'admin:' 'http://localhost:8080/exist/rest/db?_xpath=repo:install-and-deploy-from-db("/db/system/repo/init.xar")'
done