+++
date = "2018-02-19"
publishdate = "2018-02-21"
title = "Pilosa 0.8.8 Released"
author = "Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/pilosa-0-8-8-released/banner.png"
overlay_color = "blue" # blue, green, or light
+++

Pilosa has seen a handful of releases since [v0.6.0](/blog/pilosa-0-6-0-released/) was announced. Pilosa [v0.7.0](https://github.com/pilosa/pilosa/releases/tag/v0.7.0) was released on October 10, 2017, with a number of minor features including XOR and [BETWEEN](/docs/latest/query-language/#range-bsi) support, [BSI imports](/docs/latest/administration/#importing-field-values), [Sum](/docs/latest/query-language/#sum) queries, and more. [v0.8.0](https://github.com/pilosa/pilosa/releases/tag/v0.8.0) was released on November 15 with [Diagnostics](/docs/administration/#diagnostics), and the latest patch [v0.8.8](https://github.com/pilosa/pilosa/releases/tag/v0.8.8) was released this week with a [revamp of Roaring tests](https://github.com/pilosa/pilosa/pull/1118/files) to stamp out a whole class of bugs. Combined with other patch releases, these represent 161 contributions from 10 contributors.

<!--more-->

v0.8.8 includes:

### Roaring test generation
Despite having a huge number of tests in our Roaring Bitmaps package, we've uncovered a few bugs since the RLE implementation, each one identifying a previously undiscovered corner case. The last few [bug reports](https://github.com/pilosa/pilosa/issues/1103) prompted an [overhaul](https://github.com/pilosa/pilosa/pull/1118/files) of our approach to testing Roaring. 

Previously, tests were defined manually, in a best-effort sort of way. Now, we have a more automated system for defining a large, comprehensive series of tests, based on concise description structures. We define several container-sized bit patterns (e.g. all bits set, alternating bits set, etc.), plus the expected output of every operation we support on every binary combination of those bit patterns. Then we run each combination through each operation for every pair of possible [container types](/blog/adding-rle-support/). We can expand coverage as needed by defining new bit patterns. At present this checks the correctness of 3168 roaring operations! This approach has, so far, uncovered at least [six bugs](https://github.com/pilosa/pilosa/pull/1118) that might have eluded us for much longer otherwise.

In short, this means many new bugs in Roaring will be easier to fix, and will likely uncover any other instances of the same bug at the same time. Thanks to [Ferrari Huang](https://github.com/FerrariHuang) for the multiple bug reports which prompted this effort!

### Diagnostics
As of v0.8.0, Pilosa server now reports [Diagnostics](/docs/latest/administration/#diagnostics) to Pilosa Corp by default. Diagnostics are anonymous usage metrics that help us understand how Pilosa is used so we can appropriately focus our efforts on improving the software.

### v0.7.0 updates
v0.7.0 saw a number of minor improvements to query functionality, many related to BSI fields for indexing integer values.

- [Xor queries in PQL](https://github.com/pilosa/pilosa/pull/789)
- [BETWEEN support for Range queries](https://github.com/pilosa/pilosa/pull/847)
- [BSI import endpoint](https://github.com/pilosa/pilosa/pull/840)
- [Sum field queries](https://github.com/pilosa/pilosa/pull/778)
- [BSI Range queries in PQL](https://github.com/pilosa/pilosa/pull/755)

### Changelog
To see the complete list of new features, fixes, and performance improvements, check out [our releases on Github](https://github.com/pilosa/pilosa/releases).
