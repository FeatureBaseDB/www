+++
date = "2020-07-13"
publishdate = "2020-07-13"
title = "The effort behind marginal performance improvements"
author = "Kuba Podgorski and Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/marginal-performance-improvements/banner.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

A look at the amount of effort that we sometimes put into pursuing performance.

## Background

Pilosa is built on the [Roaring bitmaps](https://roaringbitmap.org/) concept, a high-performance technique for operations on compressed sets of bits. It starts by representing all data in terms of bitmaps, each defined as one of three "container types":

- Array: a list of integers indicating set bit positions.
- Bitmap: a direct binary representation of the bitmap.
- Run: a list of intervals, each indicating a contiguous "run" of set bits.

For each bitmap, its container type is chosen to minimize storage space, which keeps memory use low. Queries on the data are defined in terms of basic logical operations on pairs of bitmaps. Time-optimized operations are implemented for each pair of container types, which precludes the need for converting back and forth between container types (a drain on both memory and time). 

What we gain in query performance, we lose in added code complexity. This complexity is explained in a previous [blog post](/blog/adding-rle-support/), where we detail how four logical operations, each supporting three container types for both operands, require 27 implementation functions.

Now, I'd like to describe another dimension of complexity: in-place operations.

## The Problem

While this proliferation of type-specific implementations does wonders for speed, it can be suboptimal in terms of memory allocation. In an illustrative example, we might execute a union across two existing rows in a pilosa index, to produce a useful result, in a newly allocated container. In the case that one of the operands can be discarded, there is an opportunity to reduce memory usage by re-using that operand's container: an [in-place](https://en.wikipedia.org/wiki/In-place_algorithm) operation. Of course, this is not always possible, and very often it is much simpler to convert one container to a different type, to make use of an existing implementation.

When one of our customers' Pilosa clusters started consuming too much memory due to union-in-place operations, we had an opportunity to explore one facet of this problem. Diving into profiler logs, we noticed that most cases were a union-in-place of two **run** containers. In this case, we would always convert the first *run container* into a *bitmap container*, and then perform the operation. This union operation is fast (simply iterate over runs and set the appropriate bits), but the prerequisite type conversion has a high memory cost. We needed to eliminate this, while maintaining the speed. And so a new operation function, `unionRunRunInPlace`, was born.

Specifically, this function needs to look at a pair of *run containers*, combine them optimally, and return the result in one of the two original containers. As a graphical example, operating on input containers like this:

```
a:            |-----------------|

b:  |------------|              |---------|
```

should update container `a` to look like this:

```
a:  |-------------------------------------|
```

While this is *essentially* a basic algorithm problem, we found that the competing goals of time complexity, space complexity, and code complexity made things a bit more interesting. These functions power Pilosa's core query engine, so keeping them performant and bug-free is a top priority. This partly explains why not all operation-type-type combinations currently have an in-place version; if they did, it would more than double the number of operation functions.

## The Solution

The new `unionRunRunInPlace` went through several iterations before it settled into something both performant and maintainable. 

The first attempt was the naive one:

- Join the two slices of intervals into one.
- Sort the joined slice.
- Iterate through intervals in joined slices and merge overlapping or adjacent intervals.

This resulted in simple, understandable code, which accomplished the goal of avoiding the container type conversion. Adding a sorting step felt like the wrong approach; surely we can avoid all that additional time and memory usage. If nothing else, it became a useful baseline for benchmarking.

The next attempt looked great in terms of performance. The idea was to iterate over the runs in both containers in parallel, selecting two near-by runs, and then handling each possible case of overlap in a separate branch, updating the values in the first container along the way.

Unfortunately, it was **so** high-performance that it was nearly unreadable. It sat in limbo for a week while we fought over the responsibility of reviewing it (one reviewer remarking "I'm not sure if I should be excited or scared by the use of the `goto`"). I'm in favor of commenting code, but when understanding code crucially depends on dense comments, it may be a sign of fragility, and future maintenance problems.

Fortunately, [Kuba](https://github.com/kuba--) stepped in with a much-improved third iteration. In the interest of keeping this post relatively short, we'll just outline the approach here. Rather than iterating over *intervals*, iteration is done over *values*, while tracking a state variable indicating whether the current value is inside any interval or not. The shift to a state-based solution simplifies the code, in part by consolidating some logic into a state-update function. The inner loop again requires several branches for different interval-overlap cases, but now each branch calls the state-update function with minor differences. The resulting code is quite a bit more readable. [See for yourself](https://github.com/pilosa/pilosa/pull/2119/files)!

## The Results

Below is a chart comparing performance before and after adding `unionRunRunInPlace`. Each test case is described with a schematic representation of a bitmap: ■□□□□□□□ represents a bitmap with only the first bit set. The fourth case, a union of "all even bits" with "all odd bits", demonstrates the worst case. This is truly pathological: not only does this kind of pattern almost never happen in practice, but the specific bit pattern of "**all** even bits" is not logically possible in Roaring Bitmaps; the bitmap would be converted to a different, more efficient container type. In practice, we find that *run containers* often contain a small number of runs, so we expect the first three of these cases to be representative of real-world behavior.

![Performance Improvement](/img/blog/marginal-performance-improvements/performance-chart.png)
*Performance Improvement*

In short, the performance improvement was fantastic: an order of magnitude faster, and two orders of magnitude less memory usage. This doesn't look like a "marginal improvement," you might say. That's true, for this case in itself. As just one of five union-in-place functions, and one of 23 in-place functions, the overall effect on general query performance is tempered somewhat. Still, we're proud of the progress.
