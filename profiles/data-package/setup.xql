xquery version "3.1";

module namespace teip = "https://teipublisher.com/generator/setup";

declare namespace generator = "http://tei-publisher.com/library/generator";

import module namespace cpy = "http://tei-publisher.com/library/generator/copy";
import module namespace path = "http://tei-publisher.com/jinks/path";

declare %generator:write function teip:setup ($context as map(*)) {
    util:log("INFO", "data-package: Start copying files ..."),
    cpy:copy-collection($context),
    util:log("INFO", "data-package: copying files done.")
};
