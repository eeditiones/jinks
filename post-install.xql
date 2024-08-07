xquery version "3.0";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

sm:chgrp(xs:anyURI($target || "/modules/deploy-api.xql"), "dba"),
sm:chmod(xs:anyURI($target || "/modules/deploy-api.xql"), "rwxr-Sr-x")
