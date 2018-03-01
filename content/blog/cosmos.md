+++
date = "2018-02-22"
publishdate = "2018-02-22"
title = "Pilosa and Azure Cosmos DB: a Match Made in the Heavens"
author = "Alan Bernstein and Matt Jaffee"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/cosmos/banner.jpg"
overlay_color = "light" # blue, green, or light
+++

Pilosa is already super fast for huge data. Our next step is making it easy.

<!--more-->

### Motivation

At Pilosa, we're excited about finding new applications of the distributed bitmap index, so we have explored a number of use-cases. Some of these have been fairly application-specific, a sometimes necessary evil in evaluating a new technology. Looking ahead, we've explored several conceptual approaches to more general-purpose database connections:

- client-integrated (library)
- datastore-integrated (supercharger)
- change feed (self-updating)

Briefly, the client-integrated approach is an ORM designed to transparently handle both storing data in the canonical store, and indexing it with Pilosa. This would have to be done for every combination of programming language and database which we wanted to support, and probably isn't practical. 

The datastore-integrated approach is a relatively intrusive modification to an
existing database, augmenting the database's existing internal indexing system.
Realistically, we would probably use Pilosa as a transparent proxy to the
database, indexing writes automatically, and re-writing queries to make the best
possible use of Pilosa. This requires supporting multiple different database
APIs, but is at least programming language agnostic.

The change feed approach simply listens for updates via an existing hook. 
Many databases have this kind of functionality, and Pilosa already has some [tooling](github.com/pilosa/pdk) 
for indexing arbitrary data. 
While this option doesn't make reads any easier, 
it is a fairly straightforward way to start indexing in Pilosa without making 
intrusive modifications to your application.

Each of these approaches has advantages in different dimensions: how easy is it
to use? How well does it guarantee some level of consistency between the
canonical store and Pilosa? How much of our development time will it take?

Datastore integration is close to our long-term goal. 
We want Pilosa to be a drop-in tool to enable fast access to any data, 
and that means minimal setup and configuration. 
It's also a significant undertaking, 
especially considering that the work might be largely specific to the database system we're connecting to. 
The change feed approach is a good intermediate step in that direction — 
it is a way to reduce, or at least standardize, setup and configuration, 
providing a consistent process to connect Pilosa common data storage systems.

### Enter Azure Cosmos DB

Azure Cosmos DB is one of the newer offerings on Microsoft's Azure cloud computing platform. As a multi-model database, it provides access to your data through document, graph and table models, among others.

This means that while a user could be interacting with Azure Cosmos DB via a SQL, MongoDB, or Cassandra API, we can read the changefeed and always see changes in the same format for indexing.

One of the things we like about Azure Cosmos DB is its consistency model. Although tunable consistency is not new, the ability to select between [five consistency levels](https://docs.microsoft.com/en-us/azure/cosmos-db/consistency-levels#consistency-levels) while maintaining SLA guarantees is an interesting and novel feature. As believers in [the index as a first-class citizen](https://www.pilosa.com/blog/oscon-2017-recap-the-index-as-a-first-class-citizen/), we're happy to see consistency being handled in a more fine-grained way: consistency and availability are both crucial, broadly speaking, but it can make a lot of sense to forfeit strong consistency for performance in the context of an index.

One of the big draws of Cosmos is that it automatically indexes everything by default. Since Pilosa is an index, you might think there isn't much room for it here, and while we initially wondered that, experiments seem to suggest otherwise. Cosmos' approach to indexing is described in some detail in this [paper](http://www.vldb.org/pvldb/vol8/p1668-shukla.pdf), and it turns out that to be quite complementary to Pilosa's.

All of this makes Azure Cosmos DB and Pilosa a natural fit for each other. Pilosa needs a consistent underlying data store and support for multiple APIs. Azure Cosmos DB benefits by exposing Pilosa to enable super low latency queries for high cardinality segmentation and other query types at which Pilosa excels. Azure Cosmos DB users would benefit in this case by reducing their Cosmos Request Unit usage for queries which can be intensive and only performing simple document fetches which may fall under Azure Cosmos DB's impressive SLAs. Later on, we believe Pilosa could be incorporated more directly into Azure Cosmos DB's indexing system to provide enhanced performance in a way which is completely transparent to the end user.

Currently, we imagine deploying Pilosa into existing software stacks using Azure Cosmos DB, and using it to help power ad-hoc queries as well as data science and machine learning applications. Azure Cosmos DB can continue serving normal application business logic, but having Pilosa available alongside it opens up new avenues for iterative data exploration that may not previously have been practical.

In order to validate our theories about Azure Cosmos DB and Pilosa, we used an Azure function App to read the Azure Cosmos DB changelog and post that to the PDK using it's automated indexing functionality to get the data indexed in Pilosa. Read on for the gory details and some performance comparisons!

### Pilosa + Azure Cosmos DB

With that goal in mind, the rest is just details. We've documented our approach [here](https://github.com/pilosa/cosmosa), so try it out yourself! We did our best to include every detail in those instructions - for newcomers to Go or Cosmos - so I'll summarize here.

![Azure Cosmos DB integration diagram](/img/blog/cosmos/cosmos-integration-diagram.png)
*Crude Azure Cosmos DB integration diagram*

In addition to the data store (Azure Cosmos DB) and the index (Pilosa), the system includes a couple of other components. Adapted from one of the Azure Cosmos DB [samples](https://github.com/Azure-Samples/azure-cosmos-db-mongodb-golang-getting-started), the [cosmosla](https://github.com/jaffee/cosmosla) tool handles both data generation and Azure Cosmos DB querying via the Mongo API. The [Pilosa Dev Kit](https://github.com/pilosa/pdk) has a new `http` subcommand, which listens for arbitrary JSON data to index in Pilosa; this plays nicely with the change feed from the Azure Cosmos DB function app, which connects directly to this PDK listener.

That all sounds a little overwhelming, so I want to add some context. What does this system look like to a Azure Cosmos DB user? The database and the data generator represent existing components, and the function app is trivial; you can copy the source from our [instructions](https://github.com/pilosa/cosmosa#create-a-function-app-to-process-the-cosmosdb-change-feed). The Pilosa and PDK servers are the new components that need to be set up separately, at least for now.

What do we get for this? All the raw speed of Pilosa, and all the flexibility of Azure Cosmos DB, woven together into one supercharged system! 

Here are some timed queries into Cosmos:

| Query                                | CosmosDB      |
| -------------                        | ------------- |
| Count All Records                    | 80ms          |
| First Record                         | 32ms          |
| First Record with 3 particular tiles | 124ms         |
| Count with tile "p1"                 | 277ms         |
| Count with tile "bx"                 | 279ms         |
| Count with tile "jt"                 | 527ms         |
| Count with tile "wy"                 | 808ms         |
| Count with tile "e8"                 | 741ms         |
| Count records with p1,jt,wy          | 806ms         |

These have 5 second sleeps in between them as that seemed to make the performance better. The slower Count queries could probably have benfited from longer breaks between queries. This may have something to do with Cosmos' cost/performance structure and the number of "RUs" we had.

And here are the Pilosa queries:

| Query                                | Pilosa        |
| -------------                        | ------------- |
| Top 20 tiles                         | 20ms          |
| Count with tile "p1"                 | 9ms           |
| Count with tile "bx"                 | 7ms           |
| Count with tile "jt"                 | 8ms           |
| Count with tile "wy"                 | 8ms           |
| Count with tile "e8"                 | 11ms          |
| Count records with p1,jt,wy          | 8ms           |

This whole battery executes more or less instantly for what it's worth.

Stay tuned as we dig more into these numbers and figure out how to model filtered TopN queries in CosmosDB!

_Alan is a software engineer at Pilosa. When he’s not mapping the universe, you can find him playing with laser cutters, building fidget spinners for his dog, or practicing his sick photography skills. Find him on Twitter [@gsnark](https://twitter.com/gsnark)._

_Jaffee is a lead software engineer at Pilosa. When he’s not evangelizing independent indexes, he enjoys jiu-jitsu, building mechanical keyboards, and spending time with family. Follow him on Twitter at [@mattjaffee](https://twitter.com/mattjaffee?lang=en)._


