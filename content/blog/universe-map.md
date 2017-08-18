+++
date = "2017-08-15"
publishdate = "2017-08-15"
title = "A Complete Map of the Universe"
author = "Alan Bernstein"
author_img = "2"
image = "/img/blog/universe-map/banner.png"
overlay_color = "green" # blue, green, or light
disable_overlay = false
+++

The universe of 65536-bit sets in Roaring, that is. This post is one part debugging postmortem, one part documentation, and three parts academic deep dive on the structure that underlies Roaring Bitmaps.

<!--more-->

### Container Space

Pilosa uses Roaring Bitmaps to store large sets of integers by breaking them up into
"containers" that are 2<sup>16</sup> = 65536 bits long, and using a different
"container type" for each one, depending on what's in it. For example, the
set {0, 1, 2, 3, 6, 7, 9, 10, 14} has three equivalent representations in
Roaring:

![RLE container example](/img/blog/universe-map/rle-container-example.png)
*Small container type example*

The set contains nine elements, and in this toy example, we'll use 16-bit
numbers to store them. That means the array representation uses 9×2
bytes. The uncompressed bitmap, in which one bit is set for each number in the
set, uses two bytes, regardless of what set it represents. RLE stores the set as a
list of runs, where each run contains two 16-bit numbers (the start and end of
the run). For this set with four runs, we use (4 runs) × (2 numbers per
run) × (2 bytes per number).

Before I get into it, let's summarize some notation:

![Container terminology table](/img/blog/universe-map/container-terminology-table.png)
*Container terminology*

Roaring switches between these intelligently to minimize storage size. Which
container type is smallest? In this example, the uncompressed bitmap is, but
the answer depends on the set. Originally, with only two container types
(uncompressed bitmaps and arrays), deciding when to switch between the two for a
given container was trivial: compare the cardinality of
the set (N) to a threshold, (M<sub>A</sub>), and only use an array if
N ≤ M<sub>A</sub>. With the addition of RLE containers, this got more complicated, because
now we have to check a new attribute of the set, the number of runs of ones
N<sub>R</sub>.

Previously, we only had to decide between two one-dimensional intervals, with a
single comparison. Now, with both N and N<sub>R</sub> defining a two-dimensional
planar region that I have dubbed "container space", each container type
corresponds to a subregion with linear boundaries. These regions are illustrated
below.

![Container type decision](/img/blog/universe-map/container-type-decision.png)
*Container type decision*

M is the maximum number of bits in a container.
Note that the figure is not to scale; M is actually much larger than
M<sub>A</sub> and M<sub>R</sub>. The 2:1 ratio of M<sub>A</sub> and M<sub>R</sub> is
accurate, however.

There is an impossible region in there, why is that?

- The solid black line sloping up-right, the N = N<sub>R</sub> diagonal,
    represents sets where every set bit is isolated - all runs are length one.
    No set can be above this line, as that would mean more runs than set bits
    (but each run must have at least one bit).

- The other solid black diagonal line, N = M-N<sub>R</sub>, represents sets where
    every clear bit is isolated - all runs are as close as possible while still
    being separate. No set can be above this line, as that would mean more runs
    than clear bits (which must separate adjacent runs). If you think about the
    complementary set, it makes sense that both of these constraints must exist.

- Near the intersection of these two lines are two points, (M/2, M/2) and (M/2+1, M/2), which represent sets with
    the maximum number of single-bit runs. These are the only cases for which
    N<sub>R</sub> = M/2; N<sub>R</sub> is smaller for all other sets. 

The remaining region represents all possible sets, with container type regions
indicated by color. What about those boundaries, where do they come from?

- The line N = M<sub>A</sub> is the `ArrayMaxSize` threshold constraint: when
  cardinality is low enough, an array will always be smaller than a bitmap.
  Array size is AN, so an array is smaller than a bitmap when AN < M, or N < M/A.

- The line N<sub>R</sub> = M<sub>R</sub> is a similar `RunMaxSize` threshold constraint.
  When the number of runs is low enough, an RLE container will always be smaller
  than a bitmap. RLE size is 2RN<sub>R</sub>, so an RLE is smaller than a bitmap when 2RN<sub>R</sub> < M, or
  N<sub>R</sub> < M/(2R).

- Finally, that dotted diagonal line is the boundary between array and RLE:
  arrays are smaller than runs when AN < 2RN<sub>R</sub>, or N < 2(R/A)N<sub>R</sub>. 
  Generally, A = R, so this simplifies to N < 2N<sub>R</sub>.

I think it's a pretty diagram. It's satisfying to see a complex situation
condensed into a simple 2-D cartesian representation, even if it ignores
important complexity. There is one problem: it's not symmetric enough!

The above figure represents exactly what Pilosa does to decide a container type,
but there is another container type that Pilosa doesn't use at all:
*inverse arrays*. What if, for dense data, we store an array of the
*clear bits* instead of the set bits? Then the diagram looks like this:

![Container type decision with inverse arrays](/img/blog/universe-map/container-type-decision-with-inverse.png)
*Container type decision with inverse arrays*

Beautiful! Now, the utility of this container type is questionable, because it's
fundamentally  the same as the array type. You can even achieve the same
behavior by storing the inverse of your set. Most of all, we don't expect to
see a lot of dense data, but if we do, we can consider adding this new type.
Anyway, I'm just glad to know that there is a sort of fundamental mirror
symmetry to the diagram.

### Bugs

We made some fast progress with the [RLE work](https://github.com/pilosa/pilosa/releases/tag/v0.6.0), but while stress testing it with
large imports, we discovered some nasty bugs. For weeks we couldn't even
reproduce them consistently, but eventually we were able to trim those big
import jobs down to something more manageable. Only then did we have a chance to
diagnose the problem, and before long we figured it out: some of the container
type decision logic was flawed.

Implementing RLE was a big job, and at least four of our engineers contributed
to the branch. Two of us updated the file-read/write functions to handle RLE
containers, which is why we failed to notice that the logic for deciding
container type on file read did not exactly match the logic on write (partly
because it was hidden inside the innocuous-sounding `Bitmap.Optimize()`).
If you've implemented a binary file format  before, you might be thinking: why
is there even any logic at all for deciding a container  type while reading a
file? That's a great question, and it's answered in full by the
[Roaring storage spec](https://github.com/RoaringBitmap/RoaringFormatSpec).

TL;DR: back before RLE containers, it was trivial to infer container type from
the cardinality, which had to be stored for arrays anyway, so there was no explicit type
information in the file. With the addition of RLE, it became necessary to add
one extra bit per container, to indicate an RLE container, since the cardinality
doesn't tell you anything about that.

Of course, if perfect backward compatibility isn't critical, there are other,
more robust ways to store type information. We chose this route, including the
container type explicitly in the "descriptive header" section to guard against
similar bugs in the future. We also fixed the bug, which is the reason these
diagrams exist. Once we pinpointed the faulty decision logic, I drew these out
to convince myself of the correct behavior. Getting some thorough documentation
out of it was a nice bonus.

### Testing

We wrote a lot of debugging code to track down these bugs. One tool I wanted
early was a function `randomContainers()` to randomly generate a slice of
containers with a variety of types. I accomplished this by choosing a random
cardinality, and then generating a container with that cardinality. With some
parameter tweaking, it was easy to get an acceptable variety of types.

This lacked elegance. What I wanted was a function
`randomContainerOfType(type)` to generate one container, guaranteed to be
a specified type. Stretch goal: the container should be selected uniformly at random
from all containers of that type. How might I do that?

One approach: write a function `randomContainer(N, Nruns)` that generates
a random container with a specified cardinality and runCount. Then I can call
that within `randomContainerOfType(type)`, using randomly chosen pairs
(N, N<sub>R</sub>) that fall into the correct regions of container space. That whole
thing might be wrapped up in `randomContainers()`, which could generate
the three types with equal probability.

How does `randomContainer(N, Nruns)` work? Since `Nruns` is known,
we should probably generate an RLE container. Remember, Roaring knows how to
convert container types, so we can generate it as whatever type is most
convenient. We need an RLE container with `Nruns`, and the total number
of set bits among those runs is `N`. It's fairly easy to produce a list
of runs that satisfies these constraints. We do this by generating the
constrained run-lengths for both 1-runs and 0-runs, and converting those to the (start,
last) format used internally by Pilosa.

![Container generation](/img/blog/universe-map/container-generation-diagram.png)
*Random container generation*

The [process](https://github.com/alanbernstein/pilosa/blob/rle-fuzz/roaring/fuzz_test.go#L95) is illustrated here, and later I'll revisit one last detail about how the x and y values are generated...

### Analysis

<a href="https://xkcd.com/356/"><img src="/img/blog/universe-map/nerd-sniping.png" alt="Nerd snipe"></a>
*Nerd sniping (xkcd)*

[Jaffee](https://twitter.com/mattjaffee) saw the diagram, and made a remark similar to one that I made to myself
previously: "That array region is so small, it seems like it's not even worth
the effort." Of course, areas are deceptive in container space. There is no
direct correlation between the size of a region, and the number of sets in the
region, or the likelihood of a random set belonging to it. For example, a random
bitmap with a bit density of 5% is overwhelmingly likely to be an array, rather
than an RLE, *if the set bits are distributed uniformly randomly*.

Or that's what I assumed, at least. When someone else posed the question, I was
sniped. I had no choice but to validate that assumption. This served to satisfy
my curiosity more than anything else, but still, it's good to know I understand
what I'm working on. So, I set out to answer the question "for a randomly
chosen bitmap with M = 65536 total bits, what is the probability of falling into each of
the three regions of container space"?

I started out small: for M = 8, it's easy to enumerate all 2<sup>8</sup> possible sets
and just count the number that belong to each point in the space. This produces
a low-resolution heatmap, where position corresponds to (N, N<sub>R</sub>), and color
indicates the count for that (N, N<sub>R</sub>) pair. For such a small M, there is
hardly any sense in switching container types, so I left the region boundaries
out of the plot.

![Heatmap for M=8](/img/blog/universe-map/heatmap-8.png)
*Brute force Heatmap for M=8*

For M = 256, that doesn't work, 2<sup>256</sup> is way too big. Instead, I
sampled random sets and counted their (N, N<sub>R</sub>) in a 256x128 grid. A million
iterations captures a decent portion of the space, and with some tweaking I
figured I could fill that out.

![Heatmap for M=256](/img/blog/universe-map/heatmap-256.png)
*Stochastic heatmap for M=256*

But I wanted something that would even work for M = 65536. The same sampling
approach can be used, but the space is too big. No reasonable number of samples
could get a decent picture of the distribution.

![Stochastic Heatmap for M=65536](/img/blog/universe-map/heatmap-65536-stochastic.png) 
*Stochastic Heatmap for M=65536*

That thing that looks like a speck of dust on your screen, that's the result. Zooming in, you can see all the samples are clustered around the center of the space (32768, 16384).

![Zoomed Stochastic Heatmap for M=65536](/img/blog/universe-map/heatmap-65536-stochastic-zoom.png)
*Stochastic Heatmap for M=65536, zoom view*

See, that just seems futile. I realized there was another approach: an analytical solution. I
thought about that for a bit, then remembered the work I did on generating
random containers, which solves almost the same problem. That is, if I know how
to generate a random container given (N, N<sub>R</sub>), I should be able to count the
number of possible outcomes of that event. If I can reduce that to an analytical
expression, then I can simply examine that as a function, rather than use Monte
Carlo simulation on the impossibly large space.

After a detour through a [paper](http://www.sciencedirect.com/science/article/pii/S0898122109005744) addressing a similar but much more general
question, and verification from some helpful stackexchange [answerers](https://math.stackexchange.com/questions/2391769/what-is-the-number-of-binary-strings-of-length-n-with-exactly-r-runs-of-ones-wi), I found
the expression I needed:

![Container Space Expression](/img/blog/universe-map/container-space-expression.png)
*Analytical form of container space distribution*

If you look at the actual [`randomContainer`](https://github.com/alanbernstein/pilosa/blob/rle-fuzz/roaring/fuzz_test.go#L95) code, you can see exactly
where this comes from: the two `randomPartition` calls correspond to the
two terms in the expression. The truncated permutation [obviously](https://en.wikipedia.org/wiki/Hand-waving) chooses one of a binomial-coefficient number of possible events.

So I just needed a way to compute this, accurately and efficiently, for large
values of M, N, N<sub>R</sub>. After another few iterations, I decided that simply
summing the values of F<sub>M</sub> over the appropriate regions was the way to go. The
numbers involved are so big that it only makes sense to do this in the
logarithmic domain. That means numbers are stored as base-10 exponents, products are sums, and sums are calculated as `y + math.log10(1 + 10 ** (x-y))`. Since that sidesteps costly bignum binomial-coefficient calculations,
it helps with the speed quite a bit. It can even help avoid those log-domain sums in some cases, because
10<sup>50</sup> + 10<sup>60</sup> ≈ 10<sup>60</sup>. I'm not looking for exact integer answers
here, so I'm not too worried about an approximation that's only accurate to nine
decimal places.

![Analytical Heatmap for M=65536](/img/blog/universe-map/heatmap-65536-analytical.png)
*Analytical Heatmap for M=65536*

Finally, we come to the motivating question: when choosing one bitmap among all possible bitmaps of length 65536, what is the probability of falling into each of the container type regions? With that expression for F<sub>M</sub> in hand, it's a relatively simple matter to count the sets in each region, then divide by the total to get a probability. The answer is even simpler: all sets
are bitmaps.

Wait, that doesn't sound right... Actually, the question was wrong. We made the
mistake of trying to look at all possible sets. In that context, the vast
majority of them are right in the middle of container space, in that bright yellow spot in the bitmap
region. Let's pick just one point somewhere in the RLE region: sets with cardinality 2000, and 50 runs. There are 

22,804,597,069,819,532,660,583,786,045,040,199,183,501,681,133,949,571,581,574,
471,961,117,843,442,200,685,595,655,998,013,092,009,833,438,122,379,583,096,060,
202,845,820,303,817,291,107,720,111,436,184,863,073,472,606,535,284,594,365,552,
424,064,915,160,680,894,381,243,744,335,585,294,233,016,322,391,171,137,099,962,
713,316,168,185,225,940,347,493,675,590,676,480

(2.28×10<sup>275</sup>) bitmaps matching this criterion. But that number is
inconceivably tiny compared to the number of bitmaps with cardinality 30000 and
10000 runs: 3.69×10<sup>17459</sup>, a number with more digits than there are letters in this blog post.

The numbers for the full regions are equally absurd; there are approximately 6.6×10<sup>6651</sup> array sets, and 6.2×10<sup>5831</sup> RLE sets. The bitmap region contains the vast majority, 2.00×10<sup>19728</sup>, which is almost exactly the same as the total count.

This is what combinatorial explosion looks like in a universe containing
2<sup>65536</sup> elements. But we don't have to stop here, we just have to ask
different questions.

For example, what happens if we ask the same question about region probabilities, but for a range of
different bit depths? That is, Pilosa uses M = 65536, and M<sub>A</sub> and M<sub>R</sub> are
dictated by the 16-bit array elements. Since we're off in la-la-land anyway, why
not consider what things look like for different values of these parameters?

![Container count vs universe size](/img/blog/universe-map/container-count-vs-M.png)
*Container count vs universe size*

Getting back to the Pilosa world, what happens if we stick with M = 65536, but
restrict bit density? That is, instead of
looking at all possible bitmaps, let's look at only bitmaps with a specific cardinality. Then we can restrict the amount of the space we're looking at.
If we do this computation for a range of values of N, we can examine the container type distribution as a
function of the bit density.

![Container count vs cardinality](/img/blog/universe-map/container-count-vs-N.png)
*Container count vs cardinality*

[TODO: zoom view, remove extraneous curves, plot as frequency instead of count]

What exactly are we looking at here? The x-axis is cardinality, and the y-axis
is the count of all sets, in log scale (so 5k means 10<sup>5000</sup>). Five curves are shown, but we can focus on the first three, one for each
container type. This really shows the difference in magnitude between the
container types, and reiterates the "everything is a bitmap" conclusion. You 
can see the behavior on both sides
of the `ArrayMaxSize` threshold: for N < M<sub>A</sub>, containers can be
either arrays or runs, and arrays outweigh runs dramatically. Even at very low
cardinality, arrays are more than a googol times more likely than runs. When
N > M<sub>A</sub>, bitmaps replace arrays, and runs are still possible,
but again bitmaps outweigh them dramatically. 

[TODO this might be more confusing than it's worth?]
Further to the right, *two* more curves are shown. If using inverse arrays, 
then the sum of "iarray-runs" and "iarray-bitmap" would represent their 
count. If not, then "iarray-runs" is really just part of the "runs" curve, 
and "iarray-bitmap" is part of the bitmap curve.

At this point, my intuitive answer to Jaffee's question seems to be confirmed: The area of a region in
container space does not correspond to the count of sets belonging to the
region. The specific result suggests a new question: if the number of sets in the
RLE region is so small, why is THAT worth using as a separate container type?

One problem with the above analysis is that we're considering a uniform
distribution across all sets in the 2<sup>65536</sup>-bit universe. Even when I restricted N, I still used a uniform distribution for N<sub>R</sub>. I didn't have any
fundamental reason for picking that distribution, it's just the simplest thing
to look at. Why don't we use some distribution based on real-world data?

[TODO justify distribution]

[TODO image] container type count vs cardinality, for real (N, N_R) distribution

