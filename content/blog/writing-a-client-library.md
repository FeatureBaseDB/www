+++
date = "2017-11-03"
publishdate = "2017-11-03"
title = "Writing a Pilosa Client Library"
author = "Yüce Tekol"
author_twitter = "tklx"
author_img = "4"
image = "/img/blog/range-encoded-bitmaps/manatee-skeleton.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

In this post, we will cover creating a Pilosa client library by going through the steps of writing one in Lua.

<!--more-->

### Introduction

Pilosa server has a nice HTTP API which makes interaction with it a breeze. Essentially, a request with one or more PQL (Pilosa Query Language) queries is sent to the Pilosa server and one or more results are returned. A Pilosa client library makes it easier and less error prone to encode requests and decode responses.

[Lua](https://www.lua.org) is an embeddable scripting language which is very prevalent among game programmers due to its expressiveness, simplicity and ease of interoperability with C and C++. It is also supported by Nginx.

In this article, we are going to write a Pilosa client library in Lua. Although it won't have all of the features of official client libraries, hopefully we are going to cover the fundamentals and have a base to improve upon. Even if you are not interested in creating a client library, you may find it useful to explore the sample client.

Before delving into client library design, let's have a quick glance at the current official libraries for Pilosa.

### Client Libraries Overview

Our primary target is UNIX-like platforms, but our clients run very well on Windows too. Currently we have three official client libraries written in Go, Python and Java.

The Go client is at https://github.com/pilosa/go-pilosa. We support Go version 1.8 and up.

Our Java client at https://github.com/pilosa/java-pilosa. Java 7 and up is supported. We use Maven as our build and packaging system, so it is available to most JVM based projects and languages like Scala, Clojure and Kotlin.

Our Python client is at https://github.com/pilosa/python-pilosa and supports Python 2.7 and Python 3.4 and up. Python client library is available on [PYPI](https://pypi.python.org/pypi).

### Creating New Client Libraries

#### Getting Ready

I assume you are on a UNIX-like platform like Linux, MacOS or using [Windows Subsystem for Linux (WSL)](https://msdn.microsoft.com/en-us/commandline/wsl/about). If you are on  another platform, adapt the instructions to your particular platform.

Throughout this article, we will need to run queries against the Pilosa server so let's go ahead and launch a new Pilosa server instance. We provide [precompiled binaries](https://github.com/pilosa/pilosa/releases) for MacOS and Linux (works on WSL too), a [Homebrew package](http://brewformulas.org/Pilosa) for MacOS and a [docker image](https://hub.docker.com/r/pilosa/pilosa/). See our documentation on [acquiring and installing Pilosa](https://www.pilosa.com/docs/latest/installation/) and [starting Pilosa](https://www.pilosa.com/docs/latest/getting-started/#starting-pilosa). I assume Pilosa is running on the default address with the default scheme at `http://localhost:10101`.

While writing the code we will need to run requests against Pilosa and analyze the responses. [curl](https://curl.haxx.se) is probably the most popular tool for calling HTTP endpoints. It is usually preinstalled (or easily installable) in many UNIX-like platforms. Let's confirm Pilosa is running and curl is installed. In a terminal, execute the following:
```
curl http://localhost:10101/version
```

We should get a response similar to the following:
```
{"version":"v0.7.1"}
```

If you get the `localhost port 10101: Connection refused` error, make sure Pilosa is running on the default address.

Since we are going to write our client library in [Lua](https://www.lua.org) we will need to install Lua. But which version? When it comes to versioning, Lua takes a different stance than many mainstream languages and accepts the latest main release may not be compatible with earlier main releases. Version 5.1 seems to be the most supported version in the Lua community (due to impressive [LuaJIT](http://luajit.org) and [Nginx](https://github.com/openresty/lua-nginx-module)) so we will use it for this client library.

Although Lua 5.1 is available with most package managers for UNIX-like platforms and it's easy to compile, I found it's most convenient to use the Python based [Hererocks](https://github.com/mpeterv/hererocks) script to install it. Hererocks requires a compiler to compile Lua, so install one if you didn't already do so. Clang for MacOS, Visual Studio for Windows and GCC for Linux, WSL and other UNIX-like platforms works great. The following command creates a Lua 5.1 virtual environment with the latest LuaRocks and activates it:
```
python hererocks.py lua5.1 -l5.1 -rlatest
source lua5.1/bin/activate
```

Run `lua -v` to confirm that the virtual environment was created with the correct Lua version.

[LuaRocks](https://luarocks.org) is the defacto package manager for Lua. We are going to use it to install dependencies of our example client library. It is already installed in our virtual environment if you have used Hererocks, otherwise make sure to install it.

Let's install the dependencies for our client library:
```
luarocks install luasocket busted luacov
```

We are going to use the following layout for our client library project:
```
lua-pilosa/
    pilosa/
    tests/
    integration-tests/
    README.md
    Makefile
    make.cmd
```

The library code is in the `pilosa` directory, unit tests are in `tests` and integration tests are (predictably) in `integration-tests`.

#### Creating a Makefile
 
It's convenient to be able to use the same commands to execute tasks for all client libraries. All official Pilosa client library projects use a `Makefile` (Or its Windows equivalent `make.cmd`) which has the same targets to accomplish the same task.

We are going to create a trivial `Makefile` for our client library with the following targets:

- `test`: Runs unit tests.
- `test-all`: Runs both unit tests and integration tests.

```Makefile
.PHONY: test test-all

test:
	busted tests

test-all:
	busted tests integration-tests
```

You can see the equivalent `make.cmd` for Windows at: https://github.com/pilosa/lua-pilosa/blob/master/make.cmd

For this client we won't use any other targets, but official Pilosa clients makes use of the following extra targets:
- `cover`: Runs all tests with coverage.
- `generate`: Creates the protobuf encoder/decoder from definition files.
- `release`: Uploads the client library to the corresponding package manager.
- `doc`: Creates the documentation.
- `build`: Builds the client library.

#### ORM

The ORM component provides an API to form PQL (Pilosa Query Language) queries. The advantage of using the ORM against raw queries is usually it is less verbose and less error prone. Also, parameters are validated in the client side which allows to catch validation related errors earlier.

We are going put the ORM related code in `pilosa/orm.lua`. Let's start with defining `PQLQuery` which keeps a PQL query and the index to execute it against. `PQLQuery` constructor receives the `index` of type `Index` (to be defined a bit further) and `pql` of type string:


```lua
function PQLQuery:new(index, pql)
    self.pql = pql
    self.index = index
end

function PQLQuery:serialize()
    return self.pql
end
```

The user is not supposed to create `PQLQuery` instances directly. Instead the `Index` class is going to have helper methods to create them.

The `serialize` method returns the query as a string.

Pilosa supports many queries in the same request, which cuts down the number of HTTP calls and improves throughput. Let's create the slightly more advanced `PQLBatchQuery` class which keeps one or more PQL statements. `PQLBatchQuery` implements the same interface as `PQLQuery`, so it is usable anywhere a `PQLQuery` is expected:

```lua
function PQLBatchQuery:new(index, ...)
    local queries = {}
    for i, v in ipairs(arg) do
        table.insert(queries, v:serialize())
    end
    self.queries = queries
end

function PQLBatchQuery:add(query)
    table.insert(self.queries, query:serialize())
end

function PQLBatchQuery:serialize()
    return table.concat(self.queries)
end
```

The ORM hierarchy starts with the `Schema` class, which is used to create and cache `Index` objects:

```lua
function Schema:new()
    self.indexes = {}
end

function Schema:index(name, options)
    index = self.indexes[name]
    if index == nil then
        index = Index(name, options)
        self.indexes[name] = index
    end
    return index
end
```

A `Schema` object can be instantiated directly, but usually the user loads the schema from the Pilosa server:
```lua
-- create a schema
local schema1 = Schema()
-- load a schema
local schema2 = client.schema()
```

Once the user has a `Schema` object she can create `Index` instances. Note that the changes in the ORM side aren't persisted until the user explicitly synchronizes the schema with the Pilosa server using `client.syncSchema(schema)`.

Let's define the `Index` class:

```lua
function Index:new(name, options)
    validator.ensureValidIndexName(name)
    self.name = name
    options = options or {}
    self.options = {
        timeQuantum = options.timeQuantum or TimeQuantum.NONE
    }
    -- frames is a weak table
    self.frames = {}
    setmetatable(self.frames, { __mode = "v" })
end

function Index:frame(name, options)
    local frame = self.frames[name]
    if frame == nil then
        frame = Frame(self, name, options)
        self.frames[name] = frame
    end
    return frame
end
```

`Index` constructor takes the name of the index and its options. Currently the only option available for indexes is the time quantum.

The `Index` object keeps a cache of frames. The `frame` method creates a new `Frame` object or returns an already existing `Frame` object. We should be careful when caching `Frame` objects, since `Frame` objects have to keep a reference to their parent `Index` object. This creates a circular reference and that is problematic for languages with a reference counting memory management scheme, such as Lua and Python.

Let's add a few methods to `Index`:

```lua
function Index:rawQuery(query)
    return PQLQuery(self, query)
end

function Index:batchQuery(...)
    return PQLBatchQuery(self, unpack(arg))
end

function Index:union(...)
    return bitmapOp(self, "Union", unpack(arg))
end

-- ... SNIP ... --

function bitmapOp(index, name, ...)
    local serializedArgs = {}
    for i, a in ipairs(arg) do
        table.insert(serializedArgs, a:serialize())
    end
    local pql = string.format("%s(%s)", name, table.concat(serializedArgs, ", "))
    return PQLQuery(index, pql)
end
```

As their name tells, `rawQuery` allows the user to send any string to the Pilosa server as a query and `batchQuery` creates a `PQLBatchQuery` object with the given queries passed as arguments.

`union` method creates a `Union` query with the given bitmap queries. It calls the `bitmapOp` helper function to create the query. `intersect`, `difference` and `xor` methods are defined similarly.

Next up, the `Frame` class:
```lua
function Frame:new(index, name, options)
    validator.ensureValidFrameName(name)
    self.index = index
    self.name = name
    options = options or {}
    self.options = {
        timeQuantum = options.timeQuantum or TimeQuantum.NONE,
        inverseEnabled = options.inverseEnabled or false,
        cacheType = options.cacheType or CacheType.DEFAULT,
        cacheSize = options.cacheSize or 0
    }
end
```

The `Frame` constructor stores the parent index, its name and options with defaults. Next, a few methods which implement queries that work on frames:
```lua
function Frame:setbit(rowID, columnID, timestamp)
    local ts = ""
    if timestamp ~= nil then
        ts = string.format(", timestamp='%s'", os.date(TIME_FORMAT, timestamp))
    end
    local query = string.format("SetBit(rowID=%d, frame='%s', columnID=%d%s)", rowID, self.name, columnID, ts)
    return PQLQuery(self.index, query)
end

function Frame:bitmap(rowID)
    local query = string.format("Bitmap(rowID=%d, frame='%s')", rowID, self.name)
    return PQLQuery(self.index, query)
end

function Frame:inverseBitmap(columnID)
    local query = string.format("Bitmap(columnID=%d, frame='%s')", columnID, self.name)
    return PQLQuery(self.index, query)
end
```

Pretty straightforward. You can check rest of the methods in the [lua-pilosa]() repository.


#### Client

A Pilosa URI (Uniform Resource Identifier) tells the address of a Pilosa node. It consists of three parts: scheme, host and port. `https://index2.pilosa.com:10501` is a sample URI which points to the Pilosa node running at host `index2.pilosa.com` port `10501` and which uses `https` scheme. All parts of a Pilosa URI are optional, but at least one of the parts should be specified. The following URIs are equivalent:

- `http://localhost:10101`
- `http://localhost`
- `http://:10101`
- `localhost:10101`
- `localhost`
- `:10101`

The following Lua code defines the `URI` class which keeps a Pilosa URI. It lets us write `https://index2.pilosa.com:10501` as `URI("https", "index2.pilosa.com", 10501)`:

```lua
local DEFAULT_SCHEME = "http"
local DEFAULT_HOST = "localhost"
local DEFAULT_PORT = 10101

function URI:new(scheme, host, port)
    self.scheme = scheme
    self.host = host
    self.port = port
end

function URI:default()
    return URI(DEFAULT_SCHEME, DEFAULT_HOST, DEFAULT_PORT)
end
```

It is usually much more convenient to use a Pilosa URI as is though. We can easily parse an address and convert it to a Pilosa URI:
```lua
function URI:address(address)
    scheme, host, port = parseAddress(address)
    return URI(scheme, host, port)
end
```

The following regular expression captures all parts of a valid Pilosa URI and is being used for all official client libraries:
```
^(([+a-z]+)://)?([0-9a-z.-]+)?(:([0-9]+))?$
```

Unfortunately Lua's regular expressions support is not as powerful and each combination of URI parts should be checked separately. Below are regular expressions which should be checked from top to bottom until a match is found:
```lua
local PATTERN_SCHEME_HOST_PORT = "^([+a-z]+)://([0-9a-z.-]+):([0-9]+)$"
local PATTERN_SCHEME_HOST = "^([+a-z]+)://([0-9a-z.-]+)$"
local PATTERN_SCHEME_PORT = "^([+a-z]+)://:([0-9]+)$"
local PATTERN_HOST_PORT = "^([0-9a-z.-]+):([0-9]+)$"
local PATTERN_SCHEME = "^([+a-z]+)://$"
local PATTERN_PORT = "^:([0-9]+)$"
local PATTERN_HOST = "^([0-9a-z.-]+)$"
```

With those regular expressions defined, we can code `parseAddress` as follows:
```lua
function parseAddress(address)
    scheme, host, port = string.match(address, PATTERN_SCHEME_HOST_PORT)
    if scheme ~= nil and host ~= nil and port ~= nil then
        return scheme, host, tonumber(port)
    end
    
    scheme, host = string.match(address, PATTERN_SCHEME_HOST)
    if scheme ~= nil and host ~= nil then
        return scheme, host, DEFAULT_PORT
    end

    -- ... SNIP ... --

    host = string.match(address, PATTERN_HOST)
    if host ~= nil then
        return DEFAULT_SCHEME, host, DEFAULT_PORT
    end

    error("Not a Pilosa URI")    
end
```

Lastly, we want to convert a `URI` to a string in a format to be passed to the internal HTTP client. We call that method `normalize`:
```lua
function URI:normalize()
    return string.format("%s://%s:%d", self.scheme, self.host, self.port)
end
```

Pilosa server supports HTTP requests with JSON or [protobuf](https://github.com/google/protobuf) payload for querying, and HTTP request with JSON payload for other endpoints. It is usually more efficient to encode/decode protobuf payloads but JSON support is more prevalent. Pilosa's official client libraries all use protobuf payloads for querying, but for this client library we will use JSON payloads.

`Content-Type` and `Accept` are two HTTP headers which tell the Pilosa server the type of the payload for requests and responses in order. Most of the endpoints of Pilosa server don't require explicitly setting those endpoints and default to `application/json` but we are going to set them anyway in case the default changes in a future release.

Let's create the `PilosaClient` class:
```lua
function PilosaClient:new(uri, options)
    self.uri = uri or URI:default()
    self.options = options or {}
end
```

Most Pilosa clients can be initialized with a Pilosa URI or URIs of a cluster. But to keep things a bit simpler, we are going to assign a single URI to the client. If the user doesn't supply a URI or options, we simply set the defaults.

The actual request to a Pilosa server is not accomplished by the `PilosaClient` itself, but an underlying HTTP library, let's call it the internal HTTP client. The internal client library we use for this project doesn't support advanced features such as connection pooling.

Let's write a generic method to call Pilosa which we are going to use a bit further:

```lua
function httpRequest(client, method, path, data)
    data = data or ""
    local url = string.format("%s%s", client.uri:normalize(), path)
    local chunks = {}

    local r, status = http.request{
        url=url,
        method=method,
        source=ltn12.source.string(data),
        sink=ltn12.sink.table(chunks),
        headers=getHeaders(data)
    }

    if r == nil then
        -- status contains the error string
        error({error=status, code=0})
    end

    local response = table.concat(chunks)

    if status < 200 or status >= 300 then
        error({error=response, code=status})
    end

    return response
end
```

All Pilosa queries require specifying an index, so let's try to create one with default options using `curl`:
```
curl -X POST http://localhost:10101/index/sample-index -H "Content-Type: application/json" -H "Accept: application/json" -d ''
```

Outputs `{}` which tells that the index was created successfully. If you run the command above again, you will get the `index already exists` error with the `409 Conflict` status.

Using the `httpRequest` function we defined above, we can define the `createIndex` method of the `PilosaClient`:
```lua
function PilosaClient:createIndex(index)
    local data = setmetatable(index.options or {}, {__jsontype = "object"})
    local path = string.format("/index/%s", index.name)
    httpRequest(self, "POST", path, json.encode(data))
end
```

This method just encodes index options as the payload and creates the HTTP path using the index name. Lua uses a data structure called a table which is used both as a map and array which is a small problem when encoding an empty table. That's why we give a hint to the JSON encoder to encode the data table as an *object*.

When `createIndex` method is called with an index, it will create it on the server side if it doesn't exist. If it already exists, it will raise an error. It would be convenient to have a method which would be more forgiving to trying to create an existing index. Let's call that method `ensureIndex`:
```lua
local HTTP_CONFLICT = 409

function PilosaClient:ensureIndex(index)
    local response, err = pcall(function() self:createIndex(index) end)
    if err ~= nil and err.code ~= HTTP_CONFLICT then
        error(err)
    end
end
```

`createFrame` and `ensureFrame` methods are defined similarly.

```lua
local QueryResponse = require "pilosa.response".QueryResponse

function PilosaClient:query(query, options)
    options = options or {}
    local data = query:serialize()
    local path = string.format("/index/%s/query", query.index.name)
    local response = httpRequest(self, "POST", path, data)
    return QueryResponse(response)
end
```

#### Response

The response from the Pilosa server for a query request may be in JSON protobuf, depending on the `Accept` header in the HTTP request. The number of results in the response is the same as the PQL statements in the query request. Results in a response encoded in protobuf have the same structure with different values for fields. On the other hand, for JSON responses, the structure of a result depends on the corresponding PQL query.

Since we opted for the JSON payloads for queries, let's try a few queries using `curl` and check the responses.

We need to create the index and frame first:
```
curl -X POST http://localhost:10101/index/test-index -H "Content-Type: application/json" -H "Accept: application/json" -d ''
curl -X POST http://localhost:10101/index/test-index/frame/test-frame -H "Content-Type: application/json" -H "Accept: application/json" -d '{"options":{"inverseEnabled":true}}'
```

Let's see what we get back for the `SetBit` query:
```
curl -X POST http://localhost:10101/index/test-index/query -H "Content-Type: application/json" -H "Accept: application/json" -d 'SetBit(frame="test-frame",rowID=5, columnID=100)'
```

Outputs: `{"results":[true]}`. `SetBit` and `ClearBit` returns a boolean value, representing whether a bit was set or cleared.

Now the `SetRowAttrs` query:
```
curl -X POST http://localhost:10101/index/test-index/query -H "Content-Type: application/json" -H "Accept: application/json" -d 'SetRowAttrs(frame="test-frame",rowID=5, attr1=1, attr2="foo", attr3=true)'
```

Outputs: `{"results":[null]}`. `SetRowAttrs` and `SetColumnAttrs` always return `null`.

How about the `Bitmap` query?
```
curl -X POST http://localhost:10101/index/test-index/query -H "Content-Type: application/json" -H "Accept: application/json" -d 'Bitmap(frame="test-frame",rowID=5)'
```

Outputs: `{"results":[{"attrs":{"attr1":1,"attr2":"foo","attr3":true},"bits":[100]}]}`. The result for a `Bitmap` query includes the `attrs` map if there are any attributes set for the specified row, and the `bits` array which contains the columns for the row.

Let's try a `TopN` query:
```
curl -X POST http://localhost:10101/index/test-index/query -H "Content-Type: application/json" -H "Accept: application/json" -d 'TopN(frame="test-frame")'
```

Outputs: `{"results":[[{"id":5,"count":1}]]}`. The result is a list of count result items composed of a rowID and the count of bits set.

Next up, the `Count` query:
```
curl -X POST http://localhost:10101/index/test-index/query -H "Content-Type: application/json" -H "Accept: application/json" -d 'Count(Bitmap(frame="test-frame",rowID=5))'
```

Outputs: `{"results":[1]}`, which is the number of bits set for the given row.

Let's define the `QueryResponse` class in `pilosa/response.lua`:
```lua
function QueryResponse:new(response)
    local jsonResponse = json.decode(response)
    local results = {}
    if jsonResponse["results"] ~= nil then
        for i, result in ipairs(jsonResponse["results"]) do
            table.insert(results, QueryResult(result))
        end
    end
    self.results = results
    self.result = results[1]
end
```

The constructor of `QueryResponse` receives a string response and decodes it. It then extracts the results and stores them in the `results` property. It is convenient to access a result directly when it is the only one. So we set the `result` property the first result.

As we have seen above, a result may contain different fields depending on the corresponding query. `QueryResult` class consolidates those fields in a single data structure. Unset fields have a default value.
```lua
function QueryResult:new(result)
    if result == true then
        result = {}
    else
        result = result or {}
    end
    self.bitmap = BitmapResult(result)
    self.count = result.count or 0
    self.sum = result.sum or 0
    local countItems = {}
    if #result > 0 and result[1].id ~= nil and result[1].count ~= nil then
        for i, item in ipairs(result) do
            table.insert(countItems, CountResultItem(item))
        end
    end
    self.countItems = countItems
end

function BitmapResult:new(result)
    self.bits = result.bits or {}
    self.attributes = result.attrs or {}
end

function CountResultItem:new(id, count)
    self.id = id
    self.count = count
end
```

#### Testing

It's a good idea to separate unit tests from integration tests since integration tests depend on a running Pilosa server, and they may take longer to complete. Our `Makefile` contains two targets for testing, `make test` runs unit tests and `make test-all` runs both unit and integration tests.

Integration tests require the Pilosa server is running on the default address, but you can change it using the `PILOSA_BIND` environment variable.

### Continuous Integration

Finally we have a basic Lua client library for Pilosa, together with tests. It would be nice if the tests were run automatically when the code changed using a continuous integration service.

We use Github and Travis CI for our continuous integration infrastructure for our  projects at Pilosa. We provide a precompiled Pilosa binary which tracks the latest master so we can be sure that our client libraries work with the latest Pilosa server.

Travis CI doesn't directly support Lua, but we can use their Python image and install Lua using HereRocks like we have done in the Getting Started section. Below is the `.travis.yml` we use for this project:

```yaml
language: python
python:
  - "2.7"
before_install:
  - wget https://s3.amazonaws.com/build.pilosa.com/pilosa-master-linux-amd64.tar.gz && tar xf pilosa-master-linux-amd64.tar.gz
  - ./pilosa-master-linux-amd64/pilosa server -d http_data &
  - curl -O https://github.com/mpeterv/hererocks/raw/0.17.0/hererocks.py
  - python hererocks.py lua5.1 -l5.1 -rlatest
  - source lua5.1/bin/activate
install:
  - luarocks install luasocket busted
script:
  - make test-all
```

### Conclusion

In this article we explored the fundamentals of writing a client library for Pilosa and wrote a simple one in Lua. Hopefully the article was enjoyable and useful if you'd like to write your own or understand the current ones.

_Yüce is an Independent Software Engineer at Pilosa. Find him on Twitter at [@tklx](https://twitter.com/tklx?lang=en)._
