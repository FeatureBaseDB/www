+++
date = "2017-06-02"
publishdate = "2017-06-02"
title = "The Billion Taxi Ride Dataset with Pilosa"
author = "Matt Jaffee and Alan Bernstein"
author_img = "2"
featured = "true"
image = "/img/blog/billion-taxi-banner.png"
overlay_color = "blue" # blue, green, or light
+++

Pilosa was originally built for a very specific use case—arbitrary audience
segmentation on hundreds of millions of people with tens of millions of attributes.
As we've spun out a separate company around Pilosa, a natural first step was to
test its efficacy on other types of problems.

<!--more-->

While the user segmentation use
case has a very high number of attributes, the data is extremely sparse—most
attributes are only associated with a handful of people, and most individuals
only have a few hundred or a few thousand attributes. Pilosa handles this type
of data gracefully; in just milliseconds, one can choose any boolean combination
of the millions of attributes and find the segment of users which satisfies that
combination.

![Segmentation in Umbel](/img/blog/billion-taxi-umbel.png)

_Image courtesy of Umbel_
 
For audience segmentation, we'd happily pit Pilosa against anything out there on
similar hardware. However, if we want Pilosa to be an index which serves as a
general purpose query acceleration layer over other data stores, it will have to
be effective at more than just segmentation queries, and more than just sparse,
high cardinality data. In order to test Pilosa, we needed a dataset which had
dense, lower cardinality data, and ideally one which has been explored by other
solutions so that we could get a feel for how we might fare against them. The
[billion taxi ride dataset](http://www.nyc.gov/html/tlc/html/about/trip_record_data.shtml)
fit the bill perfectly. There are myriad blog posts analyzing the dataset with
various technologies; here are just a few:
 
* __[Analyzing 1.1 Billion NYC Taxi and Uber Trips, with a Vengeance]( http://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/)__
* __[Kx 1.1 billion taxi ride benchmark highlights advantages of kdb+ architecture]( https://kx.com/2017/01/25/kx-1-1-billion-taxi-ride-benchmark-highlights-advantages-kdb-architecture/)__
* __[Should I Stay or Should I Go? NYC Taxis at the Airport](http://chriswhong.com/open-data/should-i-stay-or-should-i-go-nyc-taxis-at-the-airport/)__

Of particular usefulness to us are the series of posts by Mark Litwintschik and the [performance comparison](http://tech.marksblogg.com/benchmarks.html) table he compiled. Here is the table for reference:

![Benchmarks](/img/blog/billion-taxi-table1.png)

We implemented the same four queries against Pilosa so that we could get some comparison of performance against other solutions.
 
Here is the English description of each query:
 
1. How many rides are there with each cab type?
2. For each number of passengers, what is the average cost of all taxi rides?
3. In each year, and for each passenger count, how many taxi rides were there?
4. For each combination of passenger count, year, and trip distance, how many rides were there - results ordered by year, and then number of rides descending.
 
Now we have a dataset and a set of queries which are far outside Pilosa's
comfort zone, along with a long list of performance comparisons on different
combinations of hardware and software.

If you'd like to learn more about how we modeled the dataset in Pilosa and
structured the queries, please see our [transportation use case post](https://www.pilosa.com/use-cases/taming-transportation-data/).
 
So instead of tens of millions of boolean attributes, we have just a few
attributes with more complex types: integers, floating point, timestamp, etc.
In short, this data is far more suitable to a relational database than the data
for which Pilosa was designed.
 
We stood up a 3-node Pilosa cluster on AWS c4.8xlarge instances, with an additional
c4.8xlarge to load the data. We used our open source [pdk](https://www.pilosa.com/docs/pdk/)
tool to load the data into Pilosa with the following arguments:

```
pdk taxi -b 2000000 -c 50 -p <pilosa-host-ip>:10101 -f
<pdk_repo_location>/usecase/taxi/greenAndYellowUrls.txt
```

This took about 2 hours and 50 minutes, which includes downloading all of the csv
files from S3, parsing them, and loading the data into Pilosa.
 
If we were to add our results to Mark's table, it would look like the following:

![Benchmarks](/img/blog/billion-taxi-table2.png)

*Note that the hardware and software are different for each setup, so direct comparisons are difficult.*

We should note that Pilosa "cheats" a bit on query 1; due to the way it stores
data, Pilosa already has this result precomputed, so the query time is mostly
network latency.
 
For the remainder of the queries, however, Pilosa does remarkably well—in
some cases beating out exotic hardware such as multi-GPU setups. The 0.177s time
on query 3 was particularly startling—performance was along the lines of 8 Nvidia
Pascal Titan Xs. It looks like kdb+/q is beating us pretty soundly,
but keep in mind that those Xeon Phi 7210s have 256 hardware threads per chip,
as well as 16GB of memory /on the package/. This gives them performance and
memory bandwidth closer to GPUs than CPUs. They're also about $2400 a piece.
 
For us, these results are enough to validate spending more time optimizing
Pilosa for uses outside of its original intent. We know that Pilosa's internal
bitmap compression format is not optimized for dense data, and more research has
been done in this area with exciting results (e.g. [roaring-run](https://arxiv.org/pdf/1603.06549.pdf)),
so we have reason to believe that there is significant room for improvement in these numbers.
