+++
date = "2017-06-08"
publishdate = "2017-06-08"
title = "Pilosa 0.4.0 Released"
author = "Cody Soyland"
author_twitter = "codysoyland"
author_img = "2"
image = "/img/blog/0.4.0-release-banner.png"
overlay_color = "blue" # blue, green, or light
+++

The Pilosa team is happy to announce the release of [Pilosa 0.4.0](https://github.com/pilosa/pilosa/releases/tag/v0.4.0), marking our second minor release since [open-sourcing on April 29](/blog/hello-world/).

This version contains 53 contributions from 13 contributors, including four volunteer contributors. Special thanks to [Alexander G.](https://github.com/kalimatas), [Damian G.](https://github.com/dgryski), [Gil R.](https://github.com/graphaelli), and [Jason N.](https://github.com/jnovinger) for your pull requests on [Github](https://github.com/pilosa/pilosa)! Also thanks to [Brian G.](https://github.com/bgyss) for creating a [Homebrew package](https://github.com/Homebrew/homebrew-core/pull/13251) for Mac installation!

<!--more-->

Some notable features include:

### StatsD metrics reporting

This release includes support for metrics reporting via the [StatsD](https://github.com/etsy/statsd) protocol. When enabled, this allows you to monitor several metrics in Pilosa like queries per second, garbage collection stats, and snapshot events. Metrics also include Datadog-compatible tags. Learn more [about our metrics support](/docs/latest/administration/#metrics) and [how to configure it](/docs/latest/configuration/#metric-service) in our documentation.

### WebUI Enhancements

The WebUI is now more useful with the addition of query input autocompletion, a cluster metadata viewer, and a syntax for frame and index creation. [Learn more about the WebUI](/docs/webui/) in our documentation.

### Docker multi-stage build

By popular demand, we cut a special release to include a [Docker multi-stage build](https://docs.docker.com/engine/userguide/eng-image/multistage-build/) with Pilosa 0.3.2 a few days after Docker 17.05 was released with that feature. This is the first minor Pilosa release with official support for Docker multi-stage builds. It is available through [Docker hub](https://hub.docker.com/r/pilosa/pilosa/) or can be built locally with `make docker`.

### Bug fixes and performance

We hope to always stay focused on stability and performance, so Pilosa 0.4.0 includes 14 bug fixes and 3 performance-related patches.

### Changelog

For this release, we've adopted the [Keep a Changelog](http://keepachangelog.com/) guidelines for managing release notes.

To see the complete list of new features, fixes, and performance improvements, check out [our changelog on Github](https://github.com/pilosa/pilosa/blob/master/CHANGELOG.md).
