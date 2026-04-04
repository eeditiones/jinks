# Building a Complete API

Let's put everything together and build a complete REST API for a simple task manager. This demonstrates CRUD operations, content negotiation, error handling, and proper HTTP status codes.

## The data model

We'll store tasks as XML documents in a database collection:

```xquery
(: A task document looks like this :)
<task id="1" created="2026-03-20T10:00:00">
    <title>Learn RESTXQ</title>
    <status>in-progress</status>
    <priority>high</priority>
    <description>Work through the RESTXQ sandbox book</description>
</task>
```

## The API module

Here's the full task API — a single XQuery module with all CRUD endpoints:

```xquery
xquery version "3.1";

module namespace tasks = "http://example.com/api/tasks";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = "http://expath.org/ns/http-client";

declare variable $tasks:COLLECTION := "/db/apps/tasks/data";
declare variable $tasks:NOT-FOUND := xs:QName("tasks:NOT_FOUND");
declare variable $tasks:BAD-REQUEST := xs:QName("tasks:BAD_REQUEST");

(: ===== LIST ===== :)

declare
    %rest:path("/api/tasks")
    %rest:GET
    %rest:query-param("status", "{$status}")
    %rest:query-param("priority", "{$priority}")
    %output:method("json")
    %output:media-type("application/json")
function tasks:list($status as xs:string*, $priority as xs:string*) {
    let $all := collection($tasks:COLLECTION)/task
    let $filtered :=
        $all
        [if (exists($status)) then status = $status else true()]
        [if (exists($priority)) then priority = $priority else true()]
    return
        array {
            for $t in $filtered
            order by $t/@created descending
            return tasks:task-to-map($t)
        }
};

(: ===== GET ONE ===== :)

declare
    %rest:path("/api/tasks/{$id}")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function tasks:get-one($id as xs:integer) {
    let $task := collection($tasks:COLLECTION)/task[@id = $id]
    return
        if ($task) then
            tasks:task-to-map($task)
        else
            error($tasks:NOT-FOUND, "Task " || $id || " not found")
};

(: ===== CREATE ===== :)

declare
    %rest:path("/api/tasks")
    %rest:POST("{$body}")
    %rest:consumes("application/json")
    %output:method("json")
    %output:media-type("application/json")
function tasks:create($body) {
    let $data := parse-json(serialize($body))
    let $title := $data?title
    return
        if (not($title)) then
            error($tasks:BAD-REQUEST, "Title is required")
        else
            let $id := tasks:next-id()
            let $task :=
                <task id="{$id}" created="{current-dateTime()}">
                    <title>{$title}</title>
                    <status>{($data?status, "todo")[1]}</status>
                    <priority>{($data?priority, "medium")[1]}</priority>
                    <description>{$data?description}</description>
                </task>
            let $_ := xmldb:store($tasks:COLLECTION, $id || ".xml", $task)
            return (
                <rest:response>
                    <http:response status="201" message="Created"/>
                </rest:response>,
                tasks:task-to-map($task)
            )
};

(: ===== UPDATE ===== :)

declare
    %rest:path("/api/tasks/{$id}")
    %rest:PUT("{$body}")
    %rest:consumes("application/json")
    %output:method("json")
    %output:media-type("application/json")
function tasks:update($id as xs:integer, $body) {
    let $existing := collection($tasks:COLLECTION)/task[@id = $id]
    return
        if (not($existing)) then
            error($tasks:NOT-FOUND, "Task " || $id || " not found")
        else
            let $data := parse-json(serialize($body))
            let $updated :=
                <task id="{$id}" created="{$existing/@created}">
                    <title>{($data?title, $existing/title/string())[1]}</title>
                    <status>{($data?status, $existing/status/string())[1]}</status>
                    <priority>{($data?priority, $existing/priority/string())[1]}</priority>
                    <description>{($data?description, $existing/description/string())[1]}</description>
                </task>
            let $_ := xmldb:store($tasks:COLLECTION, $id || ".xml", $updated)
            return tasks:task-to-map($updated)
};

(: ===== DELETE ===== :)

declare
    %rest:path("/api/tasks/{$id}")
    %rest:DELETE
    %output:method("json")
    %output:media-type("application/json")
function tasks:delete($id as xs:integer) {
    let $task := collection($tasks:COLLECTION)/task[@id = $id]
    return
        if (not($task)) then
            error($tasks:NOT-FOUND, "Task " || $id || " not found")
        else
            let $_ := xmldb:remove($tasks:COLLECTION, $id || ".xml")
            return (
                <rest:response>
                    <http:response status="204" message="No Content"/>
                </rest:response>,
                ()
            )
};

(: ===== ERROR HANDLERS ===== :)

declare
    %rest:error("tasks:NOT_FOUND")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function tasks:not-found($desc) {
    <rest:response>
        <http:response status="404"/>
    </rest:response>,
    map { "error": "not_found", "message": string($desc) }
};

declare
    %rest:error("tasks:BAD_REQUEST")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function tasks:bad-request($desc) {
    <rest:response>
        <http:response status="400"/>
    </rest:response>,
    map { "error": "bad_request", "message": string($desc) }
};

declare
    %rest:error("*")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function tasks:internal-error($desc) {
    <rest:response>
        <http:response status="500"/>
    </rest:response>,
    map { "error": "internal", "message": string($desc) }
};

(: ===== HELPERS ===== :)

declare %private function tasks:task-to-map($task as element(task)) as map(*) {
    map {
        "id": xs:integer($task/@id),
        "title": $task/title/string(),
        "status": $task/status/string(),
        "priority": $task/priority/string(),
        "description": $task/description/string(),
        "created": string($task/@created)
    }
};

declare %private function tasks:next-id() as xs:integer {
    let $existing := collection($tasks:COLLECTION)/task/@id/xs:integer(.)
    return
        if (exists($existing)) then max($existing) + 1
        else 1
};
```

## Using the API

Here's how you'd interact with this API using `curl`:

```
# List all tasks
curl http://localhost:8080/exist/restxq/api/tasks

# Create a task
curl -X POST http://localhost:8080/exist/restxq/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn RESTXQ","priority":"high"}'

# Get a specific task
curl http://localhost:8080/exist/restxq/api/tasks/1

# Update a task
curl -X PUT http://localhost:8080/exist/restxq/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status":"done"}'

# Filter by status
curl http://localhost:8080/exist/restxq/api/tasks?status=todo

# Delete a task
curl -X DELETE http://localhost:8080/exist/restxq/api/tasks/1
```

## Key patterns demonstrated

This API shows several RESTXQ best practices:

1. **Resource-oriented URLs** — `/api/tasks` for the collection, `/api/tasks/{$id}` for individual items
2. **HTTP method semantics** — GET reads, POST creates, PUT updates, DELETE removes
3. **JSON throughout** — `%output:method("json")` on every endpoint
4. **Proper status codes** — 201 for creation, 204 for deletion, 404 for missing resources, 400 for bad input
5. **Structured error handling** — `%rest:error` catches domain errors and returns JSON error objects
6. **Query parameter filtering** — `%rest:query-param` for optional filters
7. **Content negotiation** — `%rest:consumes("application/json")` enforces JSON input
8. **Separation of concerns** — helper functions handle data conversion, API functions handle HTTP

## What's next

With native RESTXQ in eXist-db, you get all of this without Roaster, without controller.xq, without OpenAPI specs — just annotated XQuery functions. The same code runs on BaseX with zero changes (minus the `xmldb:*` calls, which would need adapting to BaseX's storage API).

For production use, you'd add:
- **Authentication** with `%auth:allow-groups` (eXist extension)
- **Input validation** beyond basic type checking
- **Pagination** with `offset` and `limit` query parameters
- **ETag/caching headers** via `rest:response`
- **CORS headers** for browser access
