+++
date = "2017-10-24"
publishdate = "2017-10-24"
title = "Real Time Queries Without Compromises"
author = "Ali Cooley and Matt Jaffee"
author_twitter = "slothware"
author_img = "1"
image = "/img/blog/complex-queries-without-sacrificing-latency.jpg"
overlay_color = "green" # blue, green, or light
+++

The desire to eliminate barriers between raw data and useful insights has driven decades of engineering innovation. Countless databases, datastores, indexes, and query-level solutions promising to make this dream a reality have surfaced at regular intervals, only to fall into obscurity again as the promise remains unrealized.
<!--more-->

In the meantime, an entire class of data-centric professions has stepped in to fill the gaps left by current technologies. Those professions are doing the work of cleaning, manipulating, and analyzing data that continues to stymie our machines. So great is the demand for these skills that the [IDC predicts](https://www.idc.com/getdoc.jsp?containerId=prUS41826116) global revenues for big data and business analytics – the services these data solutions and professionals provide – will grow from $130.1 billion in 2016 to more than $203 billion in 2020. 

The rise of artificial intelligence (AI) and machine learning (ML) carries even greater promise: the [IDC estimates](https://www.idc.com/getdoc.jsp?containerId=IDC_P33198) that spending on AI/ML capabilities will grow 55%, ultimately reaching $47 billion in three short years. 

In short, industries need these technologies and services, and they’re paying massive amounts of money to get them.

Take Uber, for example. The [embattled](https://www.nytimes.com/2017/10/21/style/susan-fowler-uber.html) [tech giant’s](https://www.nytimes.com/2017/06/21/technology/uber-ceo-travis-kalanick.html) mission is to make “transportation as reliable as running water, everywhere, for everyone.” In order to accomplish this, the rideshare platform connects people who need rides to strangers with cars in mere seconds, and sweetens the deal by automating payments, thereby eliminate the awkward exchange of cash or the necessity of cards. All on a smartphone. Simple. Brilliant. 

But it takes a ton of real-time, data-based decisions to make that happen.

[Vinoth Chandar](https://www.linkedin.com/in/vinothchandar/), a staff software engineer at Uber, recently [made the case for incremental processing on Hadoop](https://www.oreilly.com/ideas/ubers-case-for-incremental-processing-on-hadoop) for _near_-real time use cases at Uber. He posits that there is a gap in capability between traditional batch oriented Hadoop, and streaming solutions like Storm, Spark Streaming and Flink; these streaming solutions work well for sub-5 minute latency requirements, and Hadoop works well when an hour or more is sufficient. So there is a gap in the 5-60 minute range; of course, the streaming solutions will work just fine here, but if you could get Hadoop to work well in that range, you can (a) save lots of cost, (b) greatly simplify your infrastructure, and (c) take advantage of more mature SQL tooling. Vinoth proposes adding some new capabilities to the Hadoop ecosystem to support incremental processing for this near real time use case. 

Vinoth's post is great by the way, and you should totally go read it. We here at Pilosa agree with everything right up to the point where he suggests continuing to use Hadoop with just a few modifications. 

To us, this seems like putting a bandaid over ravenous flesh-eating bacteria. As we mentioned above, data volumes are only increasing, and latency requirements are plummeting. So why go through Herculean efforts to retrofit a batch-oriented, high-latency technology into working for near real-time use cases, when the need for REAL real-time use cases increases every day? If you're going to collapse the lambda architecture to one side, let's make it the low latency/streaming side, not the "my results are between 5 minutes and a few hours old" side!

Most of Vinoth's arguments work pretty well whether you're talking about streaming or batch anyway. For example, if your latency requirements are not stringent, then stream processing workers can batch data store updates. Doing this will generally give you an overall increase in throughput per worker allowing you to reduce the number of workers, and therefore save on infrastructure costs. Pilosa has support for configurable batching which shows the latency/throughput trade off clearly:

| Batch Size | Time             | Latency to 1st result |
|------------|------------------|-----------------------|
|        100 | 14m47.830748948s | 0.0087s               |
|       1000 | 2m34.943978702s  | 0.0154s               |
|      10000 | 1m14.523008057s  | 0.074s                |
|     100000 | 11.044166203s    | 0.11s                 |
|    1000000 | 6.535759196s     | 0.65s                 |

Another of Vinoth's arguments is that sticking with Hadoop allows you to take advantage of the mature tooling for SQL on Hadoop, and this is certainly valid; it's always tempting to use the latest technology available, but more often than not it will cause as many problems as it solves. 

The problem with these SQL on Hadoop packages is that they are fundamentally based on Hadoop's concepts – they operate on immutable data, and require massive amounts of precomputation to be performant. Indeed, the author's proposed extensions to Hadoop revolve primarily around the ability to change and update existing data in an efficient way rather than rewriting entire partitions. Precomputation can be very useful for query acceleration, but it ultimately complicates things, particularly if you have delayed events, or "late data" as Vinoth calls it. If only there were some way to have [fast queries without precomputation...](https://www.pilosa.com/use-cases/retail-analytics/)

Vinoth's final, major argument is "fewer moving parts;" any time you can reduce the number of subsystems in a tech stack, you're probably going to make things less expensive, easier to change, simpler to manage, etc. Simplicity is one of our main foundations at Pilosa, so we're nodding enthusiastically at this bit. As we mentioned earlier on though (but it bears repeating): if you're only going to implement one arm of a lambda architecture (batch or streaming), MAKE IT STREAMING! Then take a look at [Pilosa](https://www.pilosa.com/docs/latest/introduction/) to see how you can still get complete, up to date results for complex queries without sacrificing latency.

_Ali is Pilosa's jack of all trades, including resident research nerd. Jaffee is a lead software engineer at Pilosa and is obsessed with optimization. Say hello to them on Twitter at [@ay_em_see](https://twitter.com/ay_em_see?lang=en) and [@mattjaffee](https://twitter.com/mattjaffee?lang=en)._
