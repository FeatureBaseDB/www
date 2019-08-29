+++
date = "2019-08-29"
publishdate = "2019-08-29"
title = "Apophenia -- Seeking Patterns in Randomness"
author = "Seebs"
author_twitter = "gsnark"
image = "/img/blog/apophenia/banner.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

Apophenia provides a seekable (but not cryptographically secure) PRNG
implementation. Because what's the point in random numbers if you can't
predict them?

<!--more-->

### Introduction

One of the difficulties of working with large data sets is that large data
sets take up a large amount of space. For testing and benchmarking, it
turns out that you don't care that much whether the data's accurate, but you
want to be able to generate it quickly.

To this end, I started working on a tool called `imagine` (still being
developed) which allows creating pretty large amounts of data matching
fairly arbitrary specifications of its characteristics. For instance, we
might want data in which about 1% of bits are set, or data where which bits
are set follows a Zipf distribution.

And then I had this great idea: It'd be nice, for performance testing, to be
able to compare results between data sets even when the data sets were generated
in different ways. For instance, generating all the column values for one row,
then moving on to the next row, or generating all the row values for one column,
then moving on to the next column. But what if differences between the data sets
made them perform differently? Obviously, the solution is to make sure the data
will be the same regardless of the order in which it's generated. And that
suggests that what we really want is not just a PRNG, but a PRNG where
we can seek to a given point in its output stream arbitrarily.

I spent some time looking into existing work in this field, and there's a lot
of it, but most of it is relatively computationally expensive, and really,
we don't *care* about the quality of the bits all that much -- we just need
a lot of them, really fast.

Enter the realization that AES-128 is very similar to a PRNG. If you initialize
an AES block cipher with a given key (think of that as a seed), and then treat
its 128-bit inputs as a 128-bit integers, start at 0, and count up, you get a
series of 128-bit values. This isn't a novel idea; there's a lot of existing
implementations out there that do things basically like it, but the ones I've
found typically use the counter (CTR) mode, or one of the chained modes.
Apophenia runs in the default block cipher mode, maintaining an offset/counter
internally, so we can jump to specific locations in the stream.

And I could have stopped there, and just built anything else that wanted
random values of more specific types in terms of it in our other code, but
there's some conceptual overlap, so I built some of that additional
functionality into the same package, to make the implementation more
consistent.

As a side note: Throughout, I'm referring to powers of two as `1<<N` rather than
`2^N`. This is because we're writing in Go, and in Go, `2^16` is just a fancy
way of spelling `18`, and I am trying to get out of that habit before it bites
me.

#### That sure is a lot of bits

First off, while AES-128 is usually conceived of as 16 byte inputs and outputs,
for our purposes, I wanted to treat it as a single `uint128`, only that's not
a type in Go. Enter `apophenia.Uint128`, a structure that holds a pair of
`uint64` values named `Hi` and `Lo`. (I am not the most creative person when
it comes to naming things.) So we're looking at AES-128, not so much as a
sequence of `1<<135` bits, as a sequence of `1<<128` 128-bit values. You
might wonder why it's a structure, and not `[2]uint64`; the answer is the
compiler appears to be slightly smarter about the structure, and it's a bit
less ambiguous. (Should `u[0]` be the high-order-bits? Always, or just on
big-endian hardware? Let's just call them Hi and Lo and be done.)

I was raised by mathematicians and still think it's weird when people call
a number large even though it's obviously finite, but I will admit, there's a
fair amount of space in a 128-bit input. We take advantage of this to ensure
that if you're grabbing sequences of values from the 128-bit space, you don't
get the same sequence for two different things.

For our purposes, we're mostly concerned with things where we might be iterating
over a 64-bit range of "columns", so let's use the column values as the low
order word of our `Uint128` offsets. We also often care about iterating over
rows, which tend to be significantly smaller -- a few dozen is common, but we
could reasonably expect to see values in the low billions. So we'll want
a 32-bit value that can correspond to those in some way. That leaves us only
32 more bits. Well, let's block out an 8-bit byte for the *kind* of thing being
generated -- for instance, Zipf distributions will use an entirely different
set of 128-bit values than we use when generating permutations. This doesn't
really matter very much, but hey, bits are cheap. So we have 24 bits left. What
are those for? Well, it turns out, a lot of algorithms, like Zipf generators,
want multiple consecutive values which they iterate on. Let's call those
"iterations" and give them the remaining 24 bits.

So this gives us our layout:

![Apophenia seed structure](/img/blog/apophenia/seed-structure.svg)

This allows some neat tricks. One is that you can compute the next iteration
from a given value just by incrementing the high-order word. Most of these
algorithms use only a handful of words, but just in case, the order is
selected such that overflowing iteration hops to a different sequence, not
to another seed of the same sequence. Similarly, you can just set the low-order
word to the index you want without worrying about the high-order word at all.

There's also a convenience function to create these offsets:

`OffsetFor(sequence SequenceType, seed uint32, iteration uint32, id uint64) Uint128`

#### Useful Generators

It's great to have a seekable PRNG, but usually you want values which follow
specific patterns. Apophenia provides a handful of prebuilt generators which
produce values following specific rules, built on top of an underlying `Sequence`.

The three currently-defined types are permutations (yielding the values from
0 to N-1 in an arbitrary order), zipf distributions (yielding values from 0
to N with a weighted distribution), and weighted bits. The zipf and permutation
forms are straightforward, and correspond to similar functionality in Go's
`math/rand`, although making them seekable changes them a bit. The weighted
bits, however, are a relatively unusual application.

Frequently, people look at creating weighted distributions of values; for
instance, if you generate numbers by summing evenly-distributed values, you
get a nice pretty bell curve. But in Molecula's use case, we frequently want
billions of bits with some density of bits set; we don't care so much about
weighting values within a larger range, as weighting 0 and 1.

Usually, when people want to generate bits with a given probability that
they're set, they generate a random number, then test it for a property with
the given probability of being true. For instance, if you want a 1-in-6 chance,
you might express this as `(x % 6) == 0`, which is pretty close. (It's not
exactly correct, because the range of x isn't a multiple of 6, so some numbers
are more likely than others, but with a 64-bit range, it's a very small
difference.) And this works reasonably well, but it does suggest one possible
problem, which is that you need to generate a random value for every bit you
want. What if you want to generate a *lot* of bits?

The `Weighted` generator supports this use case. You give it a density,
expressed as a ratio where the denominator is a power of 2. For instance,
you could request bits of which 3/16 are set, or 7/1024. Apophenia then
creates bundles of 128 bits, with approximately that proportion of bits set,
using bitwise operations on `Uint128`, using log2(denominator) steps. It
doesn't try to solve the case where the denominator isn't a power of two,
but it can generally be as close as you need, and it's a significant speedup.

#### Future Directions

The apophenia package is pretty new, but it's been fairly stable from an API
standpoint for a while now. It will probably get more sequence types and
functionality added, but this seems like a good point for a release. So,
here you go: https://github.com/molecula/apophenia

Note that this implementation, despite being based on a crypto function, is
not itself reasonable for cryptographic purposes; it is entirely too possible
to derive information about the "state" of the PRNG and predict its behavior.
The tradeoff from security to controlled reproducibility is intentional, and
is not a bug, but it's a real tradeoff.

#### Useful Links

Some background reading if you want to read more about this:

* https://en.wikipedia.org/wiki/Cryptographic_hash_function
* https://en.wikipedia.org/wiki/Advanced_Encryption_Standard
* https://crypto.stackexchange.com/questions/32495/how-to-convert-aes-to-a-prng-in-order-to-run-nist-statistical-test-suite
* https://github.com/paragonie/seedspring
