+++
date = "2019-09-18"
publishdate = "2019-09-18"
title = "Pilosa 1.4 Released"
author = "Matthew Jaffee"
author_twitter = "mattjaffee"
author_img = "2"
image = "/img/blog/pilosa-1-4-released/banner.png"
overlay_color = "blue" # blue, green, or light
featured = "true"
+++

Yesterday we cut Pilosa v1.4.0 — our first new minor version since
April! While we haven't made an official release since then, several
of [Molecula's](https://www.molecula.com/) clients have been using
much of the new Pilosa code for some time and some of the improvements
are **vast**.

<!--more-->

This release has a variety of fixes, changes, and additions, and you
can get all the gory details in [the
changelog](https://github.com/pilosa/pilosa/blob/master/CHANGELOG.md).
I would, however, like to call out a few of the more interesting
developments, and go into more detail on the general theme of "worker
pools".

### Callouts

- [Improved startup time](https://github.com/pilosa/pilosa/pull/1988)
  by concurrently loading fragment data. This makes it possible to
  iterate faster when working with large data sets in Pilosa, and to
  recover from failures more quickly.
- [Using UnionInPlace for time range
  queries](https://github.com/pilosa/pilosa/pull/2041) greatly reduces
  memory allocations for these queries which improves overall
  performance and stability. This makes a night and day difference for
  workloads which query time ranges.
- [Made integer fields unbounded by using sign+magnitude
  representation](https://github.com/pilosa/pilosa/pull/1902). This
  means one no longer needs to specify the minimum or maximum values
  for an integer field ahead of time, and integers will use *exactly*
  the number of bits they need to represent the data they have on a
  per-shard basis. The range grows and shrinks automatically.
- [Added fuzz tests](https://github.com/pilosa/pilosa/pull/2004) to
  our roaring implementation, and fixed
  [a](https://github.com/pilosa/pilosa/pull/2021)
  [number](https://github.com/pilosa/pilosa/pull/2019)
  [of](https://github.com/pilosa/pilosa/pull/2017)
  [subtle](https://github.com/pilosa/pilosa/pull/2012)
  [bugs](https://github.com/pilosa/pilosa/pull/1975). Big shout out to
  our interns for tackling this project!


### Worker Pools

#### The Problem

To motivate this section, I need to describe a particular subtle issue
that has been plaguing us for some time. Pilosa runs a background task
which uses a gossip protocol to maintain cluster membership and share
metadata around the cluster. This task issues constant heartbeats to
check that all the nodes in the cluster are still around and
healthy. If a node hasn't been heard from after a particular amount of
time or number of retries, it is marked as dead and the cluster may
drop into a non-working state depending on how many replicas it has
configured. The problem we'd been having was that the gossip task
would erroneously identify nodes as having died when the cluster was
under load.

The root cause of this issue was very difficult to track down, and I'm
not sure we've 100% nailed it, but this is the best theory we have at
this time: 

Pilosa tends to have a relatively large number of objects on the
heap. This means that Go's garbage collector has to do a lot of work
during its marking phase scanning through all of the data even though
it is mostly long-lived and static. Normally this isn't too much of a
problem, though it does take a percentage of system resources. Go's GC
does almost all of its work concurrently with two very short STW
(stop-the-world) phases where it has to make sure all running threads
get to a safe point, stop them, and then do a small amount of
work. Most code is chock-full of preemption points where the runtime
can quickly stop all threads, do the GC work, and get them running
again within microseconds. It's possible, however, to write code with
very tight loops which can block GC from running for arbitrarily long
times. This is documented
[here](https://github.com/golang/go/issues/10958), and is being worked
on for future versions of Go.

What seems to happen is that Pilosa has many routines performing heavy
query processing tasks which involve tight loops that may run for a
few ms at a time. When the GC reaches a STW phase, it has to wait for
all running routines to finish whatever tight loops they are in, and
won't let new routines be scheduled until it finishes its phase. So,
every time GC has to run, there are two "spin down" phases where we have
to wait for all running threads to get out of tight loops (meanwhile
the threads which finish first are idle), *and* a significant percentage
of CPU resources are taken up by GC work.

This problem is compounded if there are many goroutines all vying for
attention from the scheduler, and there's no way to tell the scheduler
that this one tiny background task in a single one of those goroutines
is actually somewhat latency sensitive, and "hey could you maybe run
this one thing pretty regularly so that it doesn't look like this
whole machine has fallen off the face of the planet causing a total
failure of the cluster until it re-establishes contact??"

So... in addition to a variety of other improvements we've made to
reduce the amount of data and pointers visible to GC, and to reuse
memory rather than re-allocating it, we thought it might be best to
reduce the number of goroutines competing for scheduling attention at
any given time.

#### Query Pool

We [implemented](https://github.com/pilosa/pilosa/pull/2034) a
goroutine worker pool for queries. This was one of those fun cases
where things worked very well until several dimensions of scale were
being exercised simultaneously. One particular workload had huge
amounts of data — a thousand Pilosa shards *per node* (each shard is
roughly 1 million records), and was issuing dozens of concurrent
queries.

Our original design had each query launching a separate goroutine
*per-shard*, which in this case meant that tens of thousands of
goroutines were being created and destroyed every second. It is
absolutely a testament to the creators of Go and the efficiency of its
runtime that things were still more-or-less working at this scale.

The classic solution to this problem is to create a fixed pool of
long-lived goroutines and pass items of work to them through a
channel. In this case, the per-shard query processing work is pretty
CPU intensive, so there isn't much point in having concurrency beyond
the number of CPU cores available. Luckily Go provides us with a
mechanism for determining the number of logical CPUs available with
`runtime.NumCPU()`, so at startup time, we create a pool of goroutines
of that size to process queries.

Amazingly, the actual performance issue that we were experiencing
around this was not that 20,000 goroutines were popping in and out of
existence each second, which the runtime handled pretty well, but that
in some cases they were all contending for the same mutexes. We
discovered via [profiling](https://golang.org/pkg/net/http/pprof/)
that there was a lot of contention in our
[tracing](https://opentracing.io/) subsystem which probabilistically
samples queries and provides detailed timing and metadata about each
processing step. Manually disabling tracing and other sources of lock
contention resulted in similar performance to what we achieved after
implementing the worker pool. With the worker pool, however, we were
able to re-enable important services like tracing without running into
lock contention issues.

#### Ingest Pools

Query processing wasn't the only area we found where we could benefit
from worker pools. In
[#2024](https://github.com/pilosa/pilosa/pull/2024) we added a
different sort of pool which helped to make data ingest more
efficient. Pilosa often has to decide between applying writes in
memory and appending them to a file, or taking a full snapshot of a
whole data fragment. Previously, it made this decision on a
fragment-by-fragment basis, which could result in many snapshots being
taken simultaneously. Now, there is a small pool of background
routines which combs through fragments with outstanding writes, and
limits concurrent snapshotting to more efficiently use the available
I/O throughput. When the system is under heavy load, it will naturally
skew more towards append only writes, and each snapshot will be
covering more outstanding writes.

We also implemented a [worker pool for import
jobs](https://github.com/pilosa/pilosa/pull/2048) so that large
numbers of concurrent imports wouldn't spawn unlimited numbers of
goroutines potentially created the same performance and contention
issues we'd seen with queries.

### Wrapping Up

I'm very proud of the work the team has done between 1.3 and 1.4, but
more than that, I'm excited for what we already have lined up for our
next release. We decided to cut the 1.4 release with what we knew was
a fairly stable codebase, even though there were a number of
outstanding pull requests with interesting features and improvements.

Be on the lookout for another release before too long with interesting things like:

- An extension interface for dynamically adding new query
  functionality to Pilosa.
- An overhauled, and more scalable key translation system.
- New types of queries (e.g. GROUP BY with aggregates over integer fields).
- [Contributions](https://github.com/pilosa/pilosa/blob/master/CONTRIBUTING.md) from viewers like you!
