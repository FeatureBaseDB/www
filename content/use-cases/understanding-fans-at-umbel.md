+++
date = "2017-05-01"
title = "Understanding Fans at Umbel"
+++

Umbel enables Sports and Entertainment companies to sell more tickets, drive sponsorships, and understand its fans by connecting massive and disparate data sources such as ticket data, social network affinity data, geographic databases, and demographic databases to name a few. 

Pilosa enables Umbel to segment and analyze a sports team’s complete fan base.  In fact, Umbel can hold the world’s population for each team and store unlimited attributes about these fans. The Umbel app allows Umbel’s clients to answer questions about fans across multiple historical data sets. It also allows Umbel, during large events, to ingest massive amounts of data in near real time while still providing lightning fast query results in the client facing app. 
   
Pilosa is a distributed, decentralized, sparse, bitmap index - not only can it represent each attribute of a fan as a single bit, it intelligently compresses each bitmap, or in some cases doesn’t store them at all (e.g. if no bits are set), resulting in a massive reduction in the size of the index. 

Additionally, Pilosa will spread itself over a large number of hosts, increasing both the amount of space and processing power available to run queries.
  
Through a combination of distributed counting, segmentation, filtering, and sorting, Pilosa can support complex queries with miniscule latency - returning vital marketing results in near real-time.

## Data Model

Let’s take a deeper dive into how Pilosa represents fans, and what sorts of queries that would enable. The abstract representation of Pilosa’s data model is a 2 dimensional binary matrix. Pilosa divides the rows of the matrix into categories called “frames”; each frame maintains its rows in sorted order by the number of columns which are set, so it is important to pick frames wisely. 
   
To model fan data in Pilosa, one must choose what the columns represent, what the rows represent, and how the rows are divided into frames. Each column represents a single fan, and each row represent some attribute about this fan. For example if a fan is from the state of Indiana, then we would have a row for “Indiana”, a column for this particular person, and the bit at their intersection would be set.
   
We could decide that all geographic attributes would be in a frame together, which would enable queries like “Show and rank the top 5 favorite energy drinks of fans at tonight’s game from Indiana“. 

| Frame Description    | Row Name                             | Person 1      | Person 2      | ... |
|----------------------|--------------------------------------|---------------|---------------|-----|
| Geography            | Alabama<br>Arkansas<br>...           | 1<br>0<br>... | 0<br>1<br>... | ... |
| Season Ticket Holder | 2017<br>2016<br>...                  | 1<br>1<br>... | 1<br>0<br>... | ... |
| Stage Attended 2017  | Main<br>Auxillary<br>...             | 1<br>1<br>... | 1<br>0<br>... | ... |
| Favorite Beers       | Beer 1<br>Beer 2<br>...              | 0<br>1<br>... | 0<br>1<br>... | ... |

## Querying

Using this data model, the Umbel app is able to answer important marketing questions.

Since Umbel is able to ingest massive amounts of information in near real time, a team could take data from a streaming event and use that to create high value segmented audiences during the event and then remarket to those segments during the event.  The most salient point is that Umbel is able to take new data and then use that in conjunction with queries against the complete historical data set instead of just a sample. 

For example, a marketer might want to know the people at last night’s game who are not season ticket holders, live within a certain geo, and match a look a like model for last year’s season ticket holders.  This provides a high quality lead list to the sales team.

A music festival might ask to see the top 5 car brands of the fans who went to the main stage.  This would enable the festival to sell sponsorships for this stage during next year’s festival.

## More

To learn more about Umbel, visit [umbel.com](https://www.umbel.com/)
