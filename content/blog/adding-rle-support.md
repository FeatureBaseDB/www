+++
date = "2017-06-25"
publishdate = "2017-06-25"
title = "Adding Support for Run-length Encoding to Pilosa"
author = "Matt Jaffee and Alan Bernstein"
author_img = "2"
featured = "true"
image = "/img/blog/rle-banner.png"
overlay_color = "blue" # blue, green, or light
+++

Pilosa is built on our 64-bit implementation of [Roaring bitmaps](http://roaringbitmap.org/), generally accepted as the best approach to compressed storage+computation for arbitrary bitsets. Until recently, our Roaring package was missing one important feature - [run-length encoded](https://en.wikipedia.org/wiki/Run-length_encoding) (RLE) sets! With full RLE support added in the v0.5.0 release, we wanted to share some details about its implementation.

<!--more-->

Roaring Bitmaps is a technique for compressed bitmap indexes described by Daniel Lemire et al. Their work shows that using three different representations for bitmap data results in excellent performance (storage size and computation speed) for general data. These three "container types" are integer arrays, compressed bitsets, and RLE. In addition to in-memory storage, Roaring includes a [full specification for file storage](https://github.com/RoaringBitmap/RoaringFormatSpec).

(TODO diagram of container types, all on the same data set)

When we decided to build a standalone bitmap index, Roaring was an obvious choice. Implementing it in Go, we used 64-bit keys to support high cardinality, rather than the 32-bit keys in the reference implementation. In our original use case, some features weren't crucial, namely the run-length encoded container type, which is relatively unimportant for very sparse data (TODO verify that claim; is there a better real reason for this early decision?). Aside from some minor (but binary-incompatible) differences, we followed the Roaring spec closely.

If you're familiar with RLE, this might seem like an odd topic for a blog post. RLE is one of the simplest compression techniques around; functions for encoding and decoding can be written in a handful of lines of your favorite language. Well, the key to Roaring's speed is that the computation of any operation on two containers is done on the raw containers, without modifying either one. Let's consider how the `AND` (intersect) operation works, when only the first two container types are implemented. For `A AND B`, there are three cases, `A` and `B` are arrays (array-array), `A` and `B` are bitsets (bitset-bitset), `A` is array and `B` is bitset or vice versa (array-bitset). Each of these must be implemented separately, so you start to see how Roaring operations are a bit more involved than the simple conceptual `AND` operation.

After adding the new RLE container type, we need three new functions: RLE-RLE, array-RLE, bitset-RLE. This is just for the `AND` operation; we need three new functions for the `OR` operation as well. We also support the non-commutative difference operation `ANDNOT`, which previously required four functions (bitset-array in addition to the three above), and now requires nine (array-RLE, RLE-array, bitset-RLE, RLE-bitset, RLE-RLE). We were adding the `XOR` operation in a parallel branch, so we included the new RLE `XOR` functions, for another three. That's 14 new functions just to support RLE for these four operations, and many of these are nontrivial. For example, (TODO).

And that's not all! Roaring needs to do a bunch of other things in addition to the binary operations. All of these operations need to be supported, on or with the RLE containers:

* Setting and clearing bits.
* Writing to and reading from files.
* Converting container types for optimal storage size, and deciding when to do it.
* Computing summary values on container types: count, runCount, max.
* Iterating over a Bitmap which can contain a mixture of all three container types.
* An internal `intersectionCount` function which speeds up certain queries.

## Differences from spec
(TODO I wanted to record this for posterity, but maybe a blog post isn't the best place for it)
* Operation support: early on, we only needed a subset of binary operations, notably missing were `XOR` and `NOT`.
* Incompatible file spec differences:
  * Our "cookie" is always bytes 0-3; our container count is always bytes 4-7, never bytes 2-3. This just simplifies the logic of writing and reading files. Our magic number matches the Roaring magic number (TODO which seems like an unfortunate oversight). 
  * Our cookie includes file format version in bytes 2-3 (currently equal to zero).
  * Our offset header section is always included. In the spec it is left out for small indexes, which explains why it is not rolled into the offset/key section. This is unneccessary parsing complexity for us.
  * RLE runs are serialized as [start, last], not [start, length]. (TODO this is an arbitrary choice?)
* After the container storage section is an operation log, of unspecified length. This maintains a record of updates to the index, which is processed when a file is read. For more details on this, stay tuned for an upcoming post on Pilosa architecture.

## Benchmarks
- memory
- disk
- speed
- different cardinalities
- different bit distributions - optimal for each case, mixed, etc

