+++
date = "2017-12-14"
publishdate = "2017-12-14"
title = "Secret Sauce - How is Pilosa Different"
author = "Matt Jaffee"
author_twitter = "mattjaffee"
author_img = "2"
image = "/img/blog/secret-sauce/banner.jpg"
overlay_color = "green"
disable_overlay = false
+++

By now, most of us have heard a thousand and one pitches for data products - and
if you're anything like me, you've given a few yourself. There's no real
shortcut to comparing these things - their features and abilities are the
summation of hundreds of tiny technical decisions and tradeoffs on a wide and
deep tree. Many of them are nearly identical except in a few details that may
only be important to very specific use cases - for example two competing SQL
databases. Others may inhabit completely separate branches of the tree - finding
common ground only at the root such as a document store and a graph database.
Some may have nearly identical APIs, but make wildly different performance
tradeoffs and so are only appropriate for distinct workloads.

Pilosa is not exempt from this sort of analysis, and is the product of just as
many careful technical decisions and engineering tradeoffs as anything else.
However, Pilosa differs in a major way, both technically and philosophically
from every other data product which I have encountered. In this respect, I
believe that Pilosa resides in a largely unexplored branch of the tree; one it
found based on the existing stack that it needed to fit into, and the
constraints of the problem which it was originally designed to solve.

The thing that makes Pilosa unique in the big data landscape is that it is an
index in a very pure sense. There are other big data products (Elasticsearch
comes to mind) which claim to be indexes, and in some sense they are, but there
is a key difference. Products like Elasticsearch store all the data you put into
them - a complete copy, with all the memory, storage, and processing power that
entails. The original notion of an index, however, comes from SQL and pre-SQL
mainframe databases where an index is an auxiliary datastructure which is
created and maintained alongside the original data for the purpose of improving
query performance. The crucial difference is that this data structure doesn't
replicate the original dataset, it just contains pointers to it, and because of
that it's much smaller and more manageable than a full copy of the data.

Pilosa's functionality is analagous to this stricter definition of an index, but
instead of maintaining the data structure in memory, or on disk alongside the
original data, it makes the index a first class entity in the world of big data
and dedicates a logically separate piece of infrastructure to it.

Grizzled database architects will likely balk at this notion, and indeed there
are a number of drawbacks to decoupling the index from the datastore. Increased
operational complexity, performance degredation due to IPC between components,
and consistency issues just to name a few. As we've seen time and again though,
there is a tipping point in scale where these tradeoffs make sense - it's not
unlike the decision to go from one giant SQL database running dedicated, top of
the line hardware to a few dozen Cassandra nodes in the cloud. At some point,
one must scale out rather than up, and that means dealing with distributed
systems head on.

Once you've made the leap, there are a number of clear advantages to a separated,
stand alone index. 

- index data from multiple underlying stores
- scale independently of the data storage layer
- focus on speed and availability rather than consistency and durability
- answer many aggregation and statistical queries without ever touching the data store
- tune hardware and infrastructure choices in a more granular way

Big data tech is pretty bad at indexing. There are a lot of materialized views,
denormalized tables, precomputed queries, etc. Most of these are fancy terms for
silly hacks which boil down to us having forgotten what indexes really are, and
what they're for. Have you ever written the same data to two different cassandra
tables which just had different primary keys? No. An index should save you
from doing things like that. Have you ever run an overnight batch job to update
a separate set of tables which exists to serve certain kinds of queries? Please
stop. A first class index should make this a non-issue.

We're really just starting this journey, and there are still a lot of unanswered
questions. It isn't always clear how to model one's data in Pilosa, or how to
integrate it into an existing stack. If you have multiple underlying data
stores, how do you keep track them? How do you keep Pilosa consistent with your
durable storage if it's a separate entity? We're working on answers to these
questions and many others over at github.com/pilosa and I invite you to come
collaborate with us. All of our public repositories are released under
permissive open source licenses, and we welcome any interaction - from questions
about how to use Pilosa, to pull requests fixing spelling mistakes, to feature
requests. 

_Jaffee is a lead software engineer at Pilosa. When he’s not evangelizing independent indexes, you can find him training in jiu-jitsu, woodworking, or building mechanical keyboards. Follow him on Twitter at [@mattjaffee](https://twitter.com/mattjaffee?lang=en)._
