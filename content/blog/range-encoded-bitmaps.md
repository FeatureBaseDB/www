+++
date = "2017-10-04"
publishdate = "2017-10-02"
title = "Some clever title."
author = "Travis Turner"
author_twitter = "travislturner"
author_img = "3"
image = "/img/blog/range-encoded-bitmaps/manatee-skeleton.jpg"
featured = "true"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

TODO: some blurb

<!--more-->

### Introduction

TODO: introduction

### Bitmap Encoding
To get started, let's assume that we want to catalog every member of the [Animal Kingdom](https://en.wikipedia.org/wiki/Animal) in such a way that we can easily, and efficiently, explore various species based on their traits. Because we're talking about bitmaps, an example data set might look like this:

![Example data set](/img/blog/range-encoded-bitmaps/example-dataset.svg)
*Example Data Set*


#### Equality-encoded Bitmaps

The example above shows a set of equality-encoded bitmaps, where each row—each trait—is a bitmap indicating which animals have that trait. Although it's a fairly simple concept, equality-encoding can be pretty powerful. Because it lets us represent everything as a boolean relationship (i.e. A manatee has wings: yes/no), we can perform all sorts of bitwise operations on the data.

The next diagram shows how we find all animals that are air-breating invertebrates by performing a logical AND on the `Invertebrate` and `Breathes Air` bitmaps. Based on our sample data, we can see that the Banana Slug, Garden Snail, and Wheel Bug all have both of those traits.

![Bitwise Intersection example](/img/blog/range-encoded-bitmaps/bitwise-intersection.svg)
*Bitwise Intersection of two traits*


You can get pretty far with equality-encoded bitmaps, but what about cases where a boolean value doesn't best represent the original data? What if we want to add a trait called `Weight` which represents the average weight of a particular animal, and we want to use that information to run queries filtered by weight range?

Given what we know about equality-encoded bitmaps, there are a couple of (admittedly naive) approaches that we could take. One approach would be to create a trait (bitmap) for every possible weight value, like this:

![Weight as individual bitmaps](/img/blog/range-encoded-bitmaps/weight-rows.svg)
*Weight represented as individual bitmaps*

This approach is ok, but it has a couple of limitations. First, it's not very efficient. Depending on the cardinality of values, you may need to create a lot of bitmaps to represent all possible values. Using animals as an example, the smallest animal might weigh 1 kilogram, while the largest—the blue whale—weighs 136,000 kilograms, meaning that you might need to create 136,000 bitmaps to represent all possible values. Second, if you want to filter your query by a range of weights, you'll have to perform an `OR` operations against every possible value in your range. You want all animals that weigh less than 100 kilograms? Then your query needs to perform something like (Weight=99 OR Weight=98 OR Weight=97 OR ...). You get the idea.

Instead of representing every possible value as a unique bitmap, another approach is to create buckets of weight ranges. In that case, you might have something like this:

![Weight as buckets](/img/blog/range-encoded-bitmaps/weight-buckets.svg)
*Weight represented as buckets*

One benefit to this approach is that it's a bit more efficient. It's also easier to query in that you don't have to construct a Union of many bitmaps in order to represent a range of values. The downside is that it's not as granular; by transforming 14 kilograms into the bucket 11-100 kilograms, you are losing information.

Either of those approaches are perfectly valid solutions to some problems, but for cases where cardinality is extremely high and losing information is not acceptable, we need another way to represent non-boolean values. And we need to do it in such a way that we can perform queries on ranges of values without writing really large and cumbersome `OR` operations. For that, let's talk about range-encoded bitmaps and how they avoid some of the problems that we ran into with the previous approaches.

#### Range-Encoded Bitmaps
First, let's take our example above and see what it looks like if we use range-encoded bitmaps.

![Weight as Range-Encoded bitmaps](/img/blog/range-encoded-bitmaps/weight-range-encoded-rows.svg)
*Weight as Range-Encoded bitmaps*

Representing a value with range-encoded bitmaps is similar to what we did with equality-encoding, but instead of just setting the bit that corresponds to a specific value, we also set a bit for every value greater than the actual value. For example, because a Koala Bear weighs 14kg, we set the bit for the 14kg bitmap as well as the 15kg, 16kg, 17kg, etc. Now, instead of a bitmap representing all the animals with a specific weight, a bitmap now represents all of the animals that weigh up to and including that weight.

This encoding method lets us perform those range queries that we did before, but instead of performing an `OR` operation on many different bitmaps, we can get what we want from just one or two bitmaps. For example, if we want to know which animals weigh less than 15kg, we just pull the 14kg bitmap and we're done. If we want to know which animals weigh greater than 15kg, it's a little more complicated, but not much. For that, we pull the bitmap representing the maximum weight (in our case that's the 136,000kg bitmap), and then we subtract the 15kg bitmap.

Those operations are much simpler—and much more efficient—than our previous approach. We have addressed the problem that had us `OR`'ing together dozens of bitmaps in order to find our range, and we aren't losing any information like we did in the bucketing approach. But we still have a couple of issues that make this approach less than ideal. First, we still have to keep a bitmap representing every specific weight. And on top of that, we have added the complexity and overhead of having to set a bit not just for the value we're interested in, but also for every value above that one. This would very likely introduce performance problems in a write-heavy use-case.

Ideally what we want is to have the functionality of range-encoded bitmaps with the efficiency of equality encoding. Next, we'll discuss bit-sliced indexes and see how that helps us achieve what we want.

### Bit-sliced Indexes

If we want to represent every possible value from 1 to 136,000 using range-encoded bitmaps, we have to have 136,000 bitmaps. While this would work, it's not the most efficient approach, and when the cardinality of possible values gets really high, the number of bitmaps we need to maintain can become prohibitive. Bit-sliced indexes let us represent those same values in a more efficient way.

Let's look at our example data and talk about how we would represent it using bit-sliced indexes.

![Weight as a Base-10, Bit-sliced Index](/img/blog/range-encoded-bitmaps/weight-bsi-base10.svg)
*Base-10, Bit-sliced Index*

Notice that we've broken our values into three, base-10 components. The first column of bits represents the value `295`, which is the average weight of a Manatee. Component 0 of `295` is `5`, so we set a bit in component 0, row 5. Component 1 of `295` is `9`, so we set a bit in component 1, row 9. Finally, component 2 of `295` is `2`, so we set a bit in component 0, row 2. Each component in our base-10 index requires 10 bitmaps to represent all possible values, so in the case where we need to represent values ranging from 0 to 999, we only need (3 x 10) = 30 bitmaps (as opposed to 1,000 bitmaps that would be required using our earlier approach). In our weight example, where before we were using 136,000 bitmaps to represent every possible weight, now we only need 60 bitmaps (actually, we only need 52 if we recognize that the most significant position will only ever contain 0 or 1).

So that's great, but we've basically just found a way to be more efficient with our equality-encoding strategy. Let's see what it looks like when we combine bit-sliced indexes with range-encoding.

### Range-Encoded Bit-Slice Indexes

![Weight as a Range-Encoded, Base-10, Bit-sliced Index](/img/blog/range-encoded-bitmaps/weight-bsi-range-encoded-base10.svg)
*Range-Encoded, Base-10, Bit-sliced Index*

Notice that the most significant value in each component (9 in the base-10 case) is always one. Because of this, we don't need to store the highest value. So for range-encoded bit-slice indexes, we only need 9 bitmaps to represent a base-10 component. In addition to that, we need one more bitmap to store the "Not Null" values. Basically, this indicates whether or not you have a value for that column. The next diagram shows the resulting bitmaps.

![Weight as a Range-Encoded, Base-10, Bit-sliced Index with Not-Null](/img/blog/range-encoded-bitmaps/weight-bsi-range-encoded-base10-not-null.svg)
*Range-Encoded, Base-10, Bit-sliced Index with Not-Null*

So for a 3-component value range, we need ((3 x 9) + 1) = 28 bitmaps to represent any value in the range 0 to 999. Now we have a pretty efficient way to store values, and we get the benefit of range encoding, so we can perform queries that filter on ranges. Let's take it just one step further and try encoding the base-2 representation of our value range.


#### Base-2 Components
If, instead of representing our weight values as base-10 components, we use base-2 components, then we end up with a range-encoded set of bit-sliced indexes that looks like this: 

![Weight as a Range-Encoded, Base-2, Bit-sliced Index](/img/blog/range-encoded-bitmaps/weight-bsi-range-encoded-base2.svg)
*Range-Encoded, Base-2, Bit-sliced Index*

The first column of bits represents the base-2 value `10010011`, which is the average weight of a Manatee (295 in base-10). Since component 0 and component 1 of `10010011` are both '1', we set a bit in component 0, row 1 and component 1, row 1. Since component 2 of `10010011` is '0', we set a bit in component 2, row 0 and—because this is range-encoded—in every value greater than 0. In the case of base-2 components, that means we also set the bit in component 2, row 1.

But remember, just like we saw before with bitmap 9 of the base-10 representation, bitmap 1 is always one so we don't need to store it. That leaves us with this:

![Weight as a Range-Encoded, Base-2, Bit-sliced Index with Not-Null](/img/blog/range-encoded-bitmaps/weight-bsi-range-encoded-base2-not-null.svg)
*Range-Encoded, Base-2, Bit-sliced Index with Not-Null*

With this encoding, we can represent the range of sample weights with only 9 bitmaps! Also, notice that the range-encoded, base-2 bit-sliced index is the inverse of the binary representation of the integer value. What this tells us that we represent an n-bit integer using only (n + 1) bitmaps (where the additional bitmap is the "Not Null" bitmap). For the example where we're storing the average weigth for every member of the Animal Kingdom, we can store values from 1 to 136,000 using only 19 bitmaps. Thie means that we can perform range queries on large integer values, and we don't have to store an unreasonable number of bitmaps.


### Range-Encoded Bitmaps at Pilosa
By implementing range-encoded bitmaps at Pilosa, users can now store integer values that pertain to billions of objects, and very quickly perform queries that filter by a range of values. We also support aggregation queries like `Sum()` and `Average()`. What's the average weight of winged vertibrates?

We added Range-Encoding support to [Release 0.7.0](https://github.com/pilosa/pilosa/releases/tag/v0.7.0). You should also check out the [Range-Encoding Documentation](https://www.pilosa.com/docs/latest/).

Try it out, and let us know what you think. We're always looking to make improvements and appreciate any feedback you have!

