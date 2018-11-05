+++
date = "2018-07-10"
publishdate = "2018-07-13"
title = "Pilosa 1.0 Released"
author = "Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
featured = "true"
image = "/img/blog/pilosa-1-0-released/banner.png"
overlay_color = "blue" # blue, green, or light
+++

Pilosa is happy to announce version 1.0, available as of last week! After eight feature-heavy major releases since our launch, there were a lot of loose ends to clean up. As followers of [semantic versioning](https://semver.org/), 1.0 is a big milestone, and a binding one. Although Pilosa is far from "complete", this release signifies a certain stability. We plan to support the current feature set and API through all 1.x releases, and that entails more than you might think.

<!--more-->

What's in an API, anyway? The more we thought about that question, the more answers popped up. There is an obvious place to start—our HTTP interface and query language—but it keeps going. Since we're an open-source project, the code itself is another facet of the API. Every public line of code is potentially a part of the API surface that requires support throughout 1.x.

Among the components we considered, as we were going into 1.0:

- HTTP API
- Query language
- CLI usage
- Configuration
- Data storage format
- Golang package structure and exported variables
- Multiple language-specific clients, officially supported and otherwise
- [Pilosa dev kit](https://github.com/pilosa/console), which includes examples and connectors

As we approached our 1.0 release, the ability to maintain compatibility promises became increasingly important. We began to audit all of these components for long-term support, with the primary goal of paring things down to our core functionality. Each of these components of our API surface has its own quirks, so they each need special attention.

A large portion of the work in this release focused on these API changes, but there were some more publicly visible changes as well:

- PQL syntax has been updated significantly. See the [docs](/docs/query-language/) for details.
- Frames are now known as fields, and the nesting of fields within frames no longer exists; each field exists at the top level in an index.
- Field creation has been revamped, with a more sensible field type system. For example, fields that were "rangeEnabled" are now simply fields of type "int".
- Slices are now known as shards.
- Query responses now refer to "columns" rather than "bits".
- WebUI has been removed from Pilosa, and is now available [separately](https://github.com/pilosa/webui).


### Changelog
To see the complete list of new features, fixes, and performance improvements, check out [our releases on Github](https://github.com/pilosa/pilosa/releases).
