+++
date = "2017-06-08"
publishdate = "2017-06-08"
title = "Pilosa 0.4.0 Released"
author = "Cody Soyland"
author_img = "2"
overlay_color = "green" # blue, green, or light
+++

The Pilosa team is happy to announce the release of [Pilosa 0.4.0](https://github.com/pilosa/pilosa/releases/tag/v0.4.0), marking our second minor release since [open-sourcing on April 29](/blog/hello-world/).

This version contains 53 contributions from 13 contributors, including four volunteer contributors. Special thanks to Alexander Guz, Damian Gryski, Gil Raphaelli, and Jason Novinger for your pull requests on [Github](https://github.com/pilosa/pilosa)! Also thanks to Brian Gyss for creating a [Homebrew package](https://github.com/Homebrew/homebrew-core/pull/13251) for Mac installation!

<!--more-->

### StatsD metrics reporting

This release includes support for metrics reporting via the [StatsD](https://github.com/etsy/statsd) protocol. When enabled, this allows you to monitor several metrics in Pilosa like queries/second, GC stats, and snapshot events. Metrics also include Datadog-compatible tags. Learn more [about our metrics support](/docs/administration/#metrics) and [how to configure it](/docs/configuration/#metric-service) in our documentation.

### WebUI Enhancements

The WebUI is now more useful with the ability to create and delete indexes and frames, autocomplete queries, and view cluster metadata.

### Docker multi-stage build

By popular demand, we cut a special release to include a [Docker multi-stage build](https://docs.docker.com/engine/userguide/eng-image/multistage-build/) with Pilosa 0.3.2 a few days after Docker 17.05 was released with that feature. This is the first minor Pilosa release with official support for Docker multi-stage builds. It is available through [Docker hub](https://hub.docker.com/r/pilosa/pilosa/) or can be built locally with `make docker`.

### Bug fixes and performance

We hope to always stay focused on stability and performance, so Pilosa 0.4.0 includes 14 bug fixes and 3 performance-related patches.

### Changelog

For this release, we've adopted the [Keep a Changelog](http://keepachangelog.com/) guidelines for managing release notes. The [Pilosa 0.4.0 changelog](https://github.com/pilosa/pilosa/blob/master/CHANGELOG.md) contains more information about this release.
