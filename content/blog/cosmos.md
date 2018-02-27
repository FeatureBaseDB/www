+++
date = "2018-02-22"
publishdate = "2018-02-22"
title = "Pilosa and Cosmos DB: a Match Made in the Heavens"
author = "Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/cosmos/banner.jpg"
overlay_color = "light" # blue, green, or light
+++

Pilosa is already super fast for huge data. Our next step is making it easy.

<!--more-->

## Motivation

At Pilosa, we're excited about finding new applications of the distributed bitmap index, so we have explored a number of use-cases. Some of these have been fairly application-specific, a sometimes necessary evil in evaluating a new technology. Looking ahead, we've explored several conceptual approaches to more general-purpose database connections:

- client-integrated (library)
- datastore-integrated (supercharger)
- change feed (self-updating)

Briefly, the client-integrated approach is an ORM designed to transparently handle both storing data in the canonical store, and indexing it with Pilosa. The datastore-integrated approach is a relatively intrusive modification to an existing database, augmenting the database's existing internal indexing system. The change feed approach simply listens for updates via an existing hook.

Each of these approaches has advantages in different dimensions: how easy is it to use, as an application developer? How well does it guarantee some level of consistency between the canonical store and Pilosa? How much of our development time will it take?

Datastore integration is close to our long-term goal. We want Pilosa to be a drop-in tool to enable fast access to any data, and that means minimal setup and configuration. It's also a significant undertaking, especially considering that the work might be largely specific to the database system we're connecting to. The change feed approach is a good intermediate step in that direction - it is a way to reduce, or at least standardize, setup and configuration, providing a consistent process to connect Pilosa with a commonly used database system.

## Enter Cosmos DB

Cosmos DB is one of the newer offerings on Microsoft's Azure cloud computing platform. As a multi-model database, it provides access to your data through document, graph and table models, among others. 
This means that while a user could be interacting with CosmosDB via a SQL, MongoDB, or Cassandra API, we can read the changefeed and always see changes in the same format for indexing.


One of the things I like about Cosmos DB is its consistency model. Although tunable consistency is not new, the ability to select, per read, between [five consistency levels](https://docs.microsoft.com/en-us/azure/cosmos-db/consistency-levels#consistency-levels) is an interesting and novel feature. As believers in [the index as a first-class citizen](https://www.pilosa.com/blog/oscon-2017-recap-the-index-as-a-first-class-citizen/), we're happy to see consistency being handled in a more fine-grained way: consistency and availability are both crucial, broadly speaking, but it can make a lot of sense to forfeit consistency for speed, in the context of an index. [compare with cassandra consistency?]

One of the big draws of Cosmos is that it automatically indexes everything by default. Since Pilosa is an index, you might think there isn't much room for it here, and while we initially wondered that, experiments seem to suggest otherwise. Cosmos' approach to indexing is described in some detail in this [paper](http://www.vldb.org/pvldb/vol8/p1668-shukla.pdf), and it turns out that to be quite complementary to Pilosa's.

All of this makes Cosmos DB and Pilosa a natural fit for each other. Pilosa needs a consistent underlying data store and support for multiple APIs. Cosmos DB benefits by exposing Pilosa to enable super low latency queries for high cardinality segmentation and other query types at which Pilosa excels. CosmosDB users would benefit in this case by reducing their Cosmos Request Unit usage for queries which can be intensive and only performing simple document fetches which may fall under Cosmos DB's impressive SLAs. Later on, we believe Pilosa could be incorporated more directly into Cosmos DB's indexing system to provide enhanced performance in a way which is completely transparent to the end user.

In order to validate our theories about Cosmos DB and Pilosa, we used an Azure function App to read the CosmosDB changelog and post that to the PDK using it's automated indexing functionality to get the data indexed in Pilosa. Read on for the gory details and some performance comparisons!

## Pilosa + Cosmos DB

With that goal in mind, the rest is just details. We've documented our approach [here](https://github.com/pilosa/cosmosa), so try it out yourself! We did our best to include every detail in those instructions - for newcomers to Go or Cosmos - so I'll summarize here.

![Cosmos DB integration diagram](/img/blog/cosmos/cosmos-integration-diagram.png)
*Cosmos DB integration diagram, courtesy of Jaffee*

In addition to the data store (Cosmos DB) and the index (Pilosa), the system includes a couple of other components. Adapted from one of the Cosmos DB [samples](https://github.com/Azure-Samples/azure-cosmos-db-mongodb-golang-getting-started), the [cosmosla](https://github.com/jaffee/cosmosla) tool handles both data generation and Cosmos DB querying via the Mongo API. The [Pilosa Dev Kit](https://github.com/pilosa/pdk) has a new `http` subcommand, which listens for arbitrary JSON data to index in Pilosa; this plays nicely with the change feed from the Cosmos DB function app, which connects directly to this PDK listener.

That all sounds a little overwhelming, so I want to add some context. What does this system look like to a Cosmos DB user? The database and the data generator represent existing components, and the function app is trivial; you can copy the source from our [instructions](https://github.com/pilosa/cosmosa#create-a-function-app-to-process-the-cosmosdb-change-feed). The Pilosa and PDK servers are the new components that need to be set up separately, at least for now.

What do we get for this? All the raw speed of Pilosa, and all the flexibility of Cosmos DB, woven together into one supercharged system!

[comparison numbers]
