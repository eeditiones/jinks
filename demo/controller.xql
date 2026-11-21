(: 	This is the main controller for the web application. It is called from the
	XQueryURLRewrite filter configured in web.xml. :)
xquery version "3.0";

(:~ -------------------------------------------------------
    Main controller: handles all requests not matched by
    sub-controllers.
    ------------------------------------------------------- :)

declare namespace c="http://exist-db.org/xquery/controller";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

(: Ask the package repository where TEI Publisher is installed rather than searching the whole repository root :)
declare function local:get-tp() {
    let $name := "https://e-editiones.org/apps/tei-publisher"
    return
        if ($name = repo:list()) then
            parse-xml(util:binary-to-string(repo:get-resource($name, "repo.xml")))//repo:target/string()
        else
            ()
};

let $query := request:get-parameter("q", ())
return
	(: redirect webapp root to index.xml :)
    if ($exist:path eq '') then
	   <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
	     <redirect url="{concat(request:get-uri(), '/')}"/>
	   </dispatch>
    else if ($exist:path eq '/') then
    	let $tp := local:get-tp()
    	return
			<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
			{
			if ($tp) then
                if(request:get-uri() = "/exist/" and request:get-header("X-Forwarded-URI") = "/") then
                   <redirect url="/apps/{$tp}/"/>
                else
                   <redirect url="apps/{$tp}/"/>
            else
                <redirect url="404.html"/>
			}
			</dispatch>
	else
		<ignore xmlns="http://exist.sourceforge.net/NS/exist">
            <cache-control cache="yes"/>
		</ignore>
