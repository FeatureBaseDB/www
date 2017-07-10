+++
date = "2017-07-10"
publishdate = "2017-07-10"
title = "Adding Run Length Encoding Support to Pilosa"
author = "Alan Bernstein and Matt Jaffee"
author_img = "2"
featured = "true"
image = "/img/blog/adding-rle-support/banner.png"
overlay_color = "" # blue, green, or light
disable_overlay = true
+++
<!-- red overlay added directly to banner image -->

Pilosa is built on our 64-bit implementation of [Roaring bitmaps](http://roaringbitmap.org/), generally accepted as the best approach to compressed storage+computation for arbitrary bitsets. Until recently, our Roaring package was missing one important feature - [run-length encoded](https://en.wikipedia.org/wiki/Run-length_encoding) (RLE) sets! With full RLE support added in the upcoming v0.5.0 release, we wanted to share some details about its implementation.

<!--more-->

### Roaring Basics

Roaring Bitmaps is a technique for compressed bitmap indexes described by Daniel Lemire et al. Their work shows that using three different representations for bitmap data results in excellent performance (storage size and computation speed) for general data. These three "container types" are integer arrays, uncompressed bitsets, and RLE.

Here is a concrete example of these container types, using this set of integers:

{0, 1, 2, 3, 6, 7, 9, 10, 14}.

![RLE container example](/img/blog/adding-rle-support/rle-container-example.png)
*RLE container types*

Array and run values are stored as 16-bit integers, whereas the entire bitset for this small example is only 16 bits. Clearly, the bitset representation wins in size here, but each container type is appropriate for different patterns in the data. For example, if we wanted to store a set of 32 contiguous integers, the RLE representation would be smallest. As a side note, each container has an associated key, which stores the high bits that are common to all elements in the container.

When we decided to build a standalone bitmap index, Roaring rose to the top as an excellent choice. Implementing it in Go, we used 64-bit keys to support high cardinality, rather than the 32-bit keys in the reference implementation. The RLE container was added to Roaring as an extension after we began our implementation, but as a non-critical feature, it sat on our roadmap for a while. In addition to in-memory storage, Roaring includes a [full specification for file storage](https://github.com/RoaringBitmap/RoaringFormatSpec). Aside from some minor (but binary-incompatible) differences, we followed this closely.

### Adding RLE

If you're familiar with RLE, this might seem like an odd topic for a blog post. RLE is one of the simplest compression techniques around; functions for encoding and decoding can be written in a handful of lines of your favorite language. The key to Roaring's speed is that the computation of any operation on two containers is done on the raw containers, without modifying either one. Let's consider how the `AND` (intersect) operation works, when only the first two container types are implemented. For `A AND B`, there are three cases: `A` and `B` are arrays (array-array), `A` and `B` are bitsets (bitset-bitset), `A` is array and `B` is bitset or vice versa (array-bitset). Each of these must be implemented separately, so you start to see how Roaring operations are a bit more involved than the simple conceptual `AND` operation.

After adding the new RLE container type, we need three new functions: RLE-RLE, array-RLE, bitset-RLE. This is just for the `AND` operation; we need three new functions for the `OR` operation as well. We also support the non-commutative difference operation `ANDNOT`, which previously required four functions (bitset-array in addition to the three above), and now requires nine (array-RLE, RLE-array, bitset-RLE, RLE-bitset, RLE-RLE). We were adding the `XOR` operation in a parallel branch, so we included the new RLE `XOR` functions, for another six. That's 17 new functions just to support RLE for these four operations, and many of these are nontrivial. All of these operation functions are summarized in the tables below.

![RLE operation functions](/img/blog/adding-rle-support/rle-function-tables.png)
*RLE operation functions. "x" indicates a required function; new functions are green*

Functions that operate on one RLE container tend to be more complicated, and functions that operate on two RLE containers even more so. For example, `intersectRunRun`, the function for computing `AND` for two RLE containers, simultaneously iterates over the runs in each container. For each pair of runs encountered, there are six distinct cases, one for each of the ways that two intervals can overlap with each other. `differenceRunRun` might be the trickiest of all the operations. Again, several different overlap cases must be considered, but unlike the intersect algorithm, these cases are interleaved.

And that's not all - Roaring needs to do a bunch of other things in addition to the binary operations. All of these operations need to be supported, on or with the RLE containers:

* Setting and clearing bits.
* Writing to and reading from files for persistent storage.
* Converting container types for optimal storage size, and deciding when to do it.
* Computing summary values on container types: count, runCount, max. Some of these are also nontrivial, with very clever solutions described in the [Roaring paper](https://arxiv.org/pdf/1603.06549.pdf).
* Iterating over a Bitmap which can contain a mixture of all three container types.
* An internal `intersectionCount` function which speeds up certain queries.

And of course, unit tests. Roaring is central to Pilosa, so we test it as thoroughly as possible. The RLE work consists of 1500+ new lines of feature code, plus 2500+ new lines of unit tests. Although our Roaring package is feature complete, we still have a few tasks on the todo list:

* Thorough benchmarking and testing on large, real data.
* Expanding fuzz testing.
* Examining inverted storage, for "sparse zeroes" data.

The work is ongoing in this [branch](https://github.com/pilosa/pilosa/tree/334-rle-rebased), if you'd like to check out the gritty details. We would also love for you to help by forking [Pilosa](https://github.com/pilosa/pilosa) and trying it out!

### Departures from the spec
Just for the sake of posterity:

* Operation support: early on, we only needed a subset of binary operations, notably missing were `XOR` and `NOT`.
* Incompatible file spec differences:
  * Our "cookie" is always bytes 0-3; our container count is always bytes 4-7, never bytes 2-3. This just simplifies the logic of writing and reading files. Our magic number matches the Roaring magic number.
  * Our cookie includes file format version in bytes 2-3 (equal to zero for this release).
  * Our offset header section is always included. In the spec it is left out for small bitmaps, which explains why it is not rolled into the offset/key section. This is unneccessary parsing complexity for us.
  * RLE runs are serialized as [start, last], not [start, length].
* After the container storage section is an operation log, of unspecified length. This maintains a record of updates to the bitmap, which is processed when a file is read. For more details on this, stay tuned for an upcoming post on Pilosa architecture.

<!--
link doesnt work yet
Our file format is described in some detail in the [docs](../../docs/architecture/#roaring-bitmap-storage-format).

-->

<!--
### Benchmarks
- memory
- disk
- speed
- different cardinalities
- different bit distributions - optimal for each case, mixed, etc
-->

Cover image illustration credit: [Vecteezy.com](https://vecteezy.com)
