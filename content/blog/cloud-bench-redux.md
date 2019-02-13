+++
date = "2019-02-13"
publishdate = "2019-02-13"
title = "I Hope You Like Charts: Benchmarks On 4 Clouds"
author = "Matt Jaffee"
author_twitter = "mattjaffee"
author_img = "2"
image = "/img/blog/cloud-bench-redux/banner.jpg"
overlay_color = "" # blue, green, or light
+++

_This is a follow-on post to [multi-cloud benchmarks.](../why-oci)_

Previously, we ran a number of [Pilosa](https://github.com/pilosa/pilosa)
specific benchmarks across a variety of configurations of hosts on AWS, Azure,
and Oracle cloud. Our broad strokes conclusions were that AWS was the fastest,
Oracle was the most cost effective, and that while not far behind, Azure didn't
stand out - if you work on Azure (or any other cloud incidentally) and want to
dig into this, we'd *love* to.

We've got a few exciting updates in this second edition:

1. We've added GCP to the mix!
2. After getting some feedback from the OCI team, we changed the OS image that
   we're using which provided a pretty good boost in some benchmarks and solved
   the mystery of performance differences between the `VM.Standard2.16` and the
   `BM.Standard2.52` instances.
3. We re-ran the AWS `c5.9xlarge` benchmarks on Amazon Linux to be equitable
   with the Oracle benchmarks.
4. We ran some low level memory bandwidth benchmarks.
5. We've updated our
   [tooling](https://github.com/pilosa/infrastructure/tree/master/terraform/examples)
   to make it significantly easier to add new configurations to our existing
   results on [data.world](https://data.world/jaffee/benchmarks).
   
   
### Overview
   
So, if you'll recall, we had a suite of queries that we ran against Pilosa
clusters configured in each cloud, as well as a set of microbenchmarks that just
ran on one instance of each cluster.

So, without further ado, here is the full set of configurations that we've
benchmarked against. These are the aggregate numbers across each *cluster*, not
for a single instance of the given type.


| Cloud | Instance Type              | Num | OS           | Cost/ Hr | CPUs | Mem (GB) | NVME SSDs |
|-------|----------------------------|----: |--------------|--------: |-----: |--------: |----------: |
| OCI   | VM.Standard2.16            |   3 | Oracle Linux |    3.06 |   96 |     720 |         0 |
| OCI   | VM.Standard2.16            |   3 | Ubuntu       |    3.06 |   96 |     720 |         0 |
| GCP   | custom-36-73728-discounted |   3 | Ubuntu       |    3.18 |  108 |     216 |         0 |
| OCI   | BM.Standard2.52            |   1 | Oracle Linux |    3.32 |  104 |     768 |         0 |
| OCI   | BM.Standard2.52            |   1 | Ubuntu       |    3.32 |  104 |     768 |         0 |
| Azure | Standard_F32s_v2           |   3 | Ubuntu       |    4.05 |   96 |     192 |         0 |
| GCP   | custom-36-73728            |   3 | Ubuntu       |    4.54 |  108 |     216 |         0 |
| AWS   | c5.9xlarge                 |   3 | Ubuntu       |    4.59 |  108 |     216 |         0 |
| AWS   | c5.9xlarge                 |   3 | Amazon Linux |    4.59 |  108 |     216 |         0 |
| Azure | Standard_F16               |   6 | Ubuntu       |    4.80 |   96 |     192 |         0 |
| OCI   | BM.HPC2.36                 |   2 | Oracle Linux |    5.40 |  144 |     768 |         2 |
| OCI   | BM.HPC2.36                 |   2 | Ubuntu       |    5.40 |  144 |     768 |         2 |
| OCI   | VM.DenseIO2.16             |   3 | Ubuntu       |    6.12 |   96 |     720 |         6 |
| AWS   | r5d.12xlarge               |   2 | Ubuntu       |   6.91  |   96 |     768 |         4 |
| AWS   | r5d.12xlarge               |   2 | Amazon Linux |   6.91  |   96 |     768 |         4 |
| Azure | Standard_E64s_v3           |   2 | Ubuntu       |   7.26  |  128 |     864 |         0 |

_"CPUs" here is the number of logical cores as reported by `/proc/cpuinfo` - usually that means hyperthreads, though for Azure's F16, it does mean physical cores._

There are a few nuances to note here. Oracle and Amazon provide custom linux
distributions (both based on CentOS), and we've run some of the configurations
on both Ubuntu and CentOS. Azure and GCP didn't seem to have hand curated Linux
derivatives and they did have official Ubuntu images, so we used those.

Now, Google does some interesting things with GCP: [custom instance types](https://cloud.google.com/compute/docs/machine-types#custom_machine_types), and
[sustained use discounts](https://cloud.google.com/compute/docs/sustained-use-discounts#sud_custom).

We created a `custom-36-73728` instance to be equivalent to AWS's c5.9xlarge -
we're even able to specify that we want Skylake class CPUs. Now, the base price
for this custom instance is about $1.51/hr which is almost exactly the same as
AWS's c5.9xlarge at $1.53/hr. However, if we run the instance for more than 25%
of a month, we start getting discounted *automatically*. Long story short, if we
keep the instance running for a month, the effective price is $1.06/hr — a 30%
discount! We look at both the full price and discounted price in our
cost/performance comparisons, the discounted price is associated with the
instance type called `custom-36-73728-discounted`.

Note that while all the providers have some form of "reserved" pricing where you
can commit in advance to a year or more of usage for a steep discount, Google is
the only one I'm aware of with any kind of totally automatic discounting.

### Microbenchmarks

Let's look first at IntersectionCount which is a simple, single-threaded benchmark with no I/O:

![IntersectionCount](/img/blog/cloud-bench-redux/perf/benchmarkfragment-intersectioncount.png)

Immediately, we can see the Oracle Linux provided a big boost over Ubuntu for
the Oracle bare metal instances. `BM.HPC2.36` has dethroned `c5.9xlarge` as the
champion of CPU performance - this is pretty surprising as the AWS instance has
a faster processor on paper. Is virtualized vs bare metal the culprit? Or
perhaps differences in the memory subsytems give OCI the edge here.

Now what about basic disk I/O?

![FileWrite](/img/blog/cloud-bench-redux/perf/benchmarkfilewriterows100000.png)

Very interesting! The bare metal HPC instance using Oracle Linux with 1 SSD
outperforms the 2 SSD VM instances (running Ubuntu) both on Oracle and AWS. The
non-SSD Oracle and AWS instances also show marked improvement running their
respective official OS images instead of Ubuntu.

Let's look at the concurrent import benchmark which tests CPU, Memory, and I/O across multiple cores.

![Import16Conc50Rows](/img/blog/cloud-bench-redux/perf/benchmarkimportroaringconcurrent50rows16concurrency.png)

So it seems like the AWS c5.9xlarge holds up a little bit better under these
mixed/concurrent conditions. There are quite a few variations on the concurrent
import in the raw results, and AWS does quite well in all of them. I suspect
that high EBS bandwidth and having multiple SSDs in the `r5d` case has something
to do with this. Possible Oracle's DenseIO2.16 would have fared a bit better if
we'd run it with Oracle Linux.


### Cluster Benchmarks

Let's look at raw performance for the queries - this time around, I've posted all of the charts for your perusal, and I'll just provide some commentary on a few things:


![29WayIntersect](/img/blog/cloud-bench-redux/perf/29-way-intersect.png)

![3WayIntersect](/img/blog/cloud-bench-redux/perf/countintersectunionrowpickup-year2012-rowpickup-year2013-rowpickup-month3.png)

![GroupByCabTypeYearPass](/img/blog/cloud-bench-redux/perf/groupbyrowsfieldcab-type-rowsfieldpickup-year-rowsfieldpassenger-count.png)

![GroupByCabTypeYearMonth](/img/blog/cloud-bench-redux/perf/groupbyrowsfieldcab-type-rowsfieldpickup-year-rowsfieldpickup-month.png)

![GroupByYearPassDist](/img/blog/cloud-bench-redux/perf/groupbyrowsfieldpickup-year-rowsfieldpassenger-count-rowsfielddist-miles.png)

![TopNCabType](/img/blog/cloud-bench-redux/perf/topncab-type.png)

![TopNFiltered](/img/blog/cloud-bench-redux/perf/topndist-miles-rowpickup-year2011.png)

![TopNDistMiles](/img/blog/cloud-bench-redux/perf/topndist-miles.png)

We see all 4 clouds making appearances in the top 3 of these query benchmarks
which have no disk I/O component. AWS wins 6 of 8, and Azure comes in first or
second in 6. Oracle has 4 top-3 appearances with 1 win, and GCP has 2 3rds and
some very close 4ths. To be fair, we've only tested one GCP configuration, so
they have fewer chances to win.

### Cluster Cost/Performance

And now the cost/performance in dollars per megaquery:

![29WayIntersect](/img/blog/cloud-bench-redux/dpmq/29-way-intersect.png)

![3WayIntersect](/img/blog/cloud-bench-redux/dpmq/countintersectunionrowpickup-year2012-rowpickup-year2013-rowpickup-month3.png)

![GroupByCabTypeYearPass](/img/blog/cloud-bench-redux/dpmq/groupbyrowsfieldcab-type-rowsfieldpickup-year-rowsfieldpassenger-count.png)

![GroupByCabTypeYearMonth](/img/blog/cloud-bench-redux/dpmq/groupbyrowsfieldcab-type-rowsfieldpickup-year-rowsfieldpickup-month.png)

![GroupByYearPassDist](/img/blog/cloud-bench-redux/dpmq/groupbyrowsfieldpickup-year-rowsfieldpassenger-count-rowsfielddist-miles.png)

![TopNCabType](/img/blog/cloud-bench-redux/dpmq/topncab-type.png)

![TopNFiltered](/img/blog/cloud-bench-redux/dpmq/topndist-miles-rowpickup-year2011.png)

![TopNDistMiles](/img/blog/cloud-bench-redux/dpmq/topndist-miles.png)

GCP shows its true colors! With that automatic discounting, Google's cloud is
extremely cost effective when you're running instances the majority of the time
for periods of 1 month or more. 

Another thing to note is the huge difference that Oracle Linux makes for the
`BM.HPC2.36` instance type. In most cases it's way ahead of the version running
Ubuntu. Except that one GroupBy query where the Ubuntu version gets third and
the Olinux version is way up in 10th. Weird.

### Memory Bandwidth

On OCI, the `VM.Standard2.16` instance type runs on the `BM.Standard2.52`
hardware. We'd previously been confused when Pilosa seemed to perform better
running in a 3-node cluster of `VM.Standard2.16` than running on a single
`BM.Standard2.52` which has slightly more horsepower both in CPU and Memory than
all 3 VMs combined. One theory was that the three VMs were allocated on
different physical hosts, and had access to more memory bandwidth in aggregate
than a single `BM.Standard2.52`. To test this, we ran a large suite of memory
bandwidth benchmarks across several configurations using this really excellent
[benchmarking tool by Zack Smith](https://zsmith.co/bandwidth.php).

We ran these with varying amounts of concurrency by running multiple instances
of the `bandwidth` program in parallel and then summing each result as directed
by the documentation. However, there doesn't seem to be any mechanism for
ensuring that the same tests are running simultaneously in each instance.
Looking at the output, they seem to stay mostly in sync, but one might take the
results at higher concurrency levels with a grain of salt. What follows are
charts of a small subset of the results - there are more on
[data.world](https://data.world/jaffee/benchmarks/workspace/query?queryid=57bd3780-e1ac-4dc7-acd7-c282243d9626),
and way, way more if you run the entire suite yourself. (one run is 1500 tests,
and we ran them all on four different concurrency levels):


#### Random 1MB reads at concurrency 1, 16, 36, 52

![random-read-1-mb-conc1](/img/blog/cloud-bench-redux/bw/bwrandom-read-64-bit-size--1-mb-conc1.png)

![random-read-1-mb-conc16](/img/blog/cloud-bench-redux/bw/bwrandom-read-64-bit-size--1-mb-conc16.png)

![random-read-1-mb-conc36](/img/blog/cloud-bench-redux/bw/bwrandom-read-64-bit-size--1-mb-conc36.png)

![random-read-1-mb-conc52](/img/blog/cloud-bench-redux/bw/bwrandom-read-64-bit-size--1-mb-conc52.png)

You can really watch the `BM.Standard2.52` pull away from the `VM.Standard2.16` at higher concurrencies.

#### Random 1MB writes at concurrency 1 and 52

![random-write-1-mb-conc1](/img/blog/cloud-bench-redux/bw/bwrandom-write-64-bit-size--1-mb-conc1.png)

![random-write-1-mb-conc52](/img/blog/cloud-bench-redux/bw/bwrandom-write-64-bit-size--1-mb-conc52.png)

1 MB writes follow the same pattern.

#### Sequential 1MB reads at 1 and 52

![sequential-read-1-mb-conc1](/img/blog/cloud-bench-redux/bw/bwsequential-read-64-bit-size--1-mb-conc1.png)

![sequential-read-1-mb-conc52](/img/blog/cloud-bench-redux/bw/bwsequential-read-64-bit-size--1-mb-conc52.png)

More of the same. There are *lots* of other combinations, but the story is pretty similar all over.


#### Analysis


Essentially, it doesn't appear that the performance difference between the
`VM.Standard2.16` cluster and the `BM.Standard2.52` machine are due to memory
bandwidth constraints. At high concurrency, we often see `BM.Standard2.52`
having approximately triple the bandwidth of the `VM.Standard2.16` system. So,
for now, this mystery remains unsolved - my next theory would be that something
in the Golang runtime (perhaps the scheduler) has some performance degredation
at high core counts and is more efficient on a machine with 32 logical cores
than one with 104. This is pure speculation, however.


### Takeaways

Using official Linux images helps pretty consistently on Oracle. The story is a
lot more mixed on Amazon. I would love to know what sort of specific tuning is
responsible for this, though I'm sure there are myriad kernel parameters that
one might tweak to get the most out of a specific hardware configuration in a
multi-tenant virtualized environment.

Google's automatic discounting is a significant advantage, though in my
estimation, Oracle still wins on overall cost effectiveness. The GCP instances
never overtake OCI by much in the $/MQ department, and the `VM.Standard2.16`
instances have over 3x (!!) the memory.

Amazon still takes the best overall raw performance though Azure and OCI do pop
up. Testing OCI's DenseIO instances with Oracle Linux and figuring out how to
get NVME SSDs on Azure and GCP would likely make for more equitable all-around
comparison. It's worth noting that even without NVME, the AWS instances on EBS
still do pretty well.


### Future Work

I'd still like to do some more low level benchmarking (like the memory bandwidth
stuff) to get baseline performance of each aspect of each configuration's
hardware.

More importantly though, I think, I'd like to do more repeated runs on the same
configurations and see what kind of consistency we're getting. Some of the
results presented here are difficult to explain, but repeated runs can yield
significant variation.

Even without taking multi-tenancy into account, there are lots of factors that
contribute to inconsistency. The language runtime comes immediately to mind -
especially with garbage collection, but there are also OS tasks and other
user-level programs potentially taking resources and cluttering up the CPU
cache. Anything doing I/O is subject to the vagaries of external hardware, which
is only exacerbated in the case of network mounted storage.



_Banner Photo by Victor Rodriguez on Unsplash_
