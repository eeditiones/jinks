xquery version "3.1";

(:~
 : Site configuration module for eXist-db site apps.
 :
 : Provides common functions used by templates across all
 : apps generated from the exist-site profile.
 :)
module namespace site-config = "http://exist-db.org/site/shell-config";

(:~
 : Get the current authenticated user.
 :
 : @return the username string
 :)
declare function site-config:current-user() as xs:string {
    let $session-user := session:get-attribute("user")
    return
        if (exists($session-user) and $session-user != "") then
            $session-user
        else
            sm:id()//sm:real/sm:username/string()
};

(:~
 : Check whether the current user is authenticated (not guest).
 :
 : @return true if logged in
 :)
declare function site-config:is-logged-in() as xs:boolean {
    site-config:current-user() != "guest"
};
