+++
date = "2017-08-11"
publishdate = "2017-08-11"
title = "Pilosa 0.6.0 Released"
author = "Cody Soyland"
author_img = "2"
image = "/img/blog/pilosa-0-6-0-released/banner.png"
overlay_color = "blue" # blue, green, or light
+++

The Pilosa team is happy to announce the release of [Pilosa 0.6.0](https://github.com/pilosa/pilosa/releases/tag/v0.6.0), massively speeding up Pilosa with [Run-length Encoding](/blog/adding-rle-support/). This release comes just days after Pilosa 0.5.0, which introduced [Input Definition](/docs/input-definition/). The two releases combined represent 79 contributions from 9 contributors.

<!--more-->

This release includes:

### Run-length Encoding

[Run-length Encoding](https://en.wikipedia.org/wiki/Run-length_encoding) (RLE) is a simple technique for data compression. RLE enhances our existing Roaring implementation for improved performance and reduced data storage requirements. Read more about our Roaring implementation and RLE in our [blog post](/blog/adding-rle-support/) and [the docs](/docs/architecture/#roaring-bitmap-storage-format).

### Input Definition

Input Definition is the first in a series of features that enable real-time Extract, Transform, and Load (ETL) processing within Pilosa. While we technically shipped Input Definition in Pilosa 0.5.0 a few days ago, we decided to combine the two announcements for simplicity's sake. Read more about it in [the docs](/docs/input-definition/).

### Changelog

To see the complete list of new features, fixes, and performance improvements, check out [our changelog on Github](https://github.com/pilosa/pilosa/blob/master/CHANGELOG.md).
