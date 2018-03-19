+++
date = "2017-10-13"
title = "Retail Analytics and the Star Schema Benchmark"
+++

## Motivation

Retail transactions happen everywhere, in huge quantities. Whether you're looking at customers, purchases, or products, the data volume is enormous, and always growing. While most retailers have been using a variety of business intelligence tools to glean important information about their consumers from these transactions, this has become increasingly difficult as more and more transactions occur both in-store and online. Extracting valuable insights from all of that data is essential for survival in the cut-throat digital age: retailers have the ability to build a 360-degree understanding of their customers, track brand sentiment, build customized promotions, and even improve their store layout from detailed analyses of their transactions. However, many struggle to run fast, ad-hoc, drill-down queries, despite their growing importance in online marketplaces.

That's part of why the Star Schema Benchmark exists: a well-known test of database query performance, modeled after classical data warehousing problems, with a retail transaction flavor. When we read this [blog post](https://hortonworks.com/blog/sub-second-analytics-hive-druid/) from Hortonworks (in partnership with AtScale) about running the benchmark on Hive+Druid, we saw it as a challenge. Could we match their query times? Could we do better? Could we do it without all of the cumbersome caching and pre-computation required in the Hortonwork/AtScale benchmark? This is what we were up against:

![Hortonworks Druid results](/img/retail-analytics/results-druid.png)
*Hortonworks Druid results, scale factor 1000, [courtesy of Hortonworks](https://hortonworks.com/blog/sub-second-analytics-hive-druid/)*


## The Data

The [Star Schema Benchmark](https://www.cs.umb.edu/~poneil/StarSchemaB.PDF) (SSB) is a benchmark designed to measure transaction performance in data warehouse applications. It is based on the [TPC-H](http://www.tpc.org/tpch/) benchmark, with some well thought-out modifications, including dropping irrelevant tables and fields, and denormalization. In particular, the data is reorganized into a [star schema](https://en.wikipedia.org/wiki/Star_schema).

In the star schema terminology, the *fact table* contains *line orders*, with keys to four *dimension tables*, describing dates, customers, suppliers, and parts. Fields and relationships are shown in this diagram:

![SSB star schema diagram](/img/retail-analytics/ssb-schema-aws.png)
*SSB star schema diagram, [courtesy of AWS](https://docs.aws.amazon.com/redshift/latest/dg/tutorial-loading-data-create-tables.html)*

We used the popular [ssb-dbgen](https://github.com/electrum/ssb-dbgen) tool to generate actual data sets conforming to this schema. This is the same generator [used](https://github.com/cartershanklin/hive-druid-ssb) for the Hortonworks/AtScale benchmark. Data produced by ssb-dbgen is distributed uniformly, and there is also a consistent correlation between certain fields. Although we are curious about what happens with more skewed distributions, we don't expect a significant performance impact with Pilosa.

The data is defined in terms of a *Scale Factor* (`SF`). The size of each table (except `DATE`) varies directly with `SF`, either linearly (`LINEORDER`, `CUSTOMER`, `SUPPLIER`) or logarithmically (`PART`). This allows for a consistent data set of any desired size. We tested with SF 1, 10, and 100 before running our final import and queries with SF 1000, to match the Hortonworks/AtScale data set.

The data set contains a large number of the core entity (purchased items) stored as records in the line-orders table. Each purchase consists of several products ("line items" in the order), and the line-order table is the denormalized combination of the `LINEITEM` and `ORDER` tables of the TPC-H schema. Almost every non-key field in the above schema diagram can be thought of as an attribute of a line-order.

## Mapping

As it turns out, the star schema is an excellent match for the Pilosa data model. Pilosa was designed to work well with one core entity (in Pilosa's columns), which correspond directly to the rows of the SSB `LINEORDER` table. Each SSB attribute then gets its own frame, of varying cardinality, where each Pilosa row represents one possible value for that attribute. In short, Pilosa was designed as a grid of *people* × attributes. Recently, we've shown how to use *taxi rides* as columns instead of people, as well as *network packets* and *molecular fingerprint components*. Now, we'll show how to use *items in a transaction* as the columns.

{{< note title="Note" >}}
Note: <i>Pilosa attributes</i> are a distinct concept, not being used here.
{{< /note >}}

For example, each line-order has a customer, with corresponding geographical information: city, nation, and region. These fields contain string data, which we represent in Pilosa by mapping to rowIDs via enumeration. Supplier attributes follow the exact same model. Part (i.e., products in auto-parts store) attributes are product information, but modeled similarly with enumeration.

We also have a few more attributes describing purchase date. As in [the transportation use case](/use-cases/taming-transportation-data/), we avoided Pilosa's built-in timestamp support. This was in part because of the need to query on the "week of year" value, which is not an explicit timestamp component. We could have used Pilosa's timestamps for year and month; without a large number of time range queries, either approach is appropriate.

Finally, we have the integer-valued attributes. In the past, higher-cardinality integer attributes had to be stored in Pilosa with one bitmap per value (O(cardinality)), or bucketed (low precision). Now that Pilosa supports storing integers with Bit-Sliced Indexes, there is no longer a tradeoff between precision and storage size. BSI integers use O(log(cardinality)) bitmaps, so there is no practical limit to the cardinality. For more details on BSI, check out [Travis'](https://twitter.com/travislturner?lang=en) [introductory blog post](/blog/range-encoded-bitmaps/) or our [BSI docs](/docs/latest/data-model/#bsi-range-encoding).

### Pilosa Data Model

In the end, the data model looks something like this:

| Frame            | Description             | Type        |    Cardinality |
|------------------|-------------------------|-------------|----------------|
| lo_quantity      | Number of items ordered | BSI         |             50 |
| lo_extendedprice | Line-order price        | BSI         |           high |
| lo_discount      | Percentage discount     | BSI         |     11 [0, 10] |
| lo_revenue       | Line-order revenue      | BSI         |           high |
| lo_supplycost    | Part cost               | BSI         |           high |
| lo_profit        | Line-order profit       | BSI         |           high |
| c_city           | Customer city           | string enum |            250 |
| c_nation         | Customer nation         | string enum |             25 |
| c_region         | Customer region         | string enum |              5 |
| s_city           | Supplier city           | string enum |            250 |
| s_nation         | Supplier nation         | string enum |             25 |
| s_region         | Supplier region         | string enum |             10 |
| p_mfgr           | Part manufacturer       | string enum |              5 |
| p_category       | Part category           | string enum |             25 |
| p_brand1         | Part brand              | string enum |           1000 |
| lo_year          | Year of purchase        | integer     | 7 [1992, 1998] |
| lo_month         | Month of purchase       | integer     |     12 [1, 12] |
| lo_weeknum       | Week of purchase        | integer     |     53 [1, 53] |

Note that the source table is encoded in the prefix of the frame name.

The SSB `DATE` table includes a number of redundant fields. All of the Pilosa queries are constructed with some combination of the three date fields listed in the table. Similar omissions were made with other tables. This has no effect on query speed performance, but it does decrease the memory requirements for the Pilosa cluster.

## Importing

If you've read through some of our other use cases, you might have seen the Pilosa Development Kit ([PDK](https://github.com/pilosa/pdk)) mentioned. This is our toolkit for shoving data into Pilosa as fast as possible. In addition to some generic components, the repo includes some example usage in the `usecase` directory, which is where you can find [Jaffee's](https://twitter.com/mattjaffee?lang=en) work on the [SSB import](https://github.com/pilosa/pdk/tree/master/usecase/ssb).

Conceptually, there isn't a lot of new ground here; the mapping described above is straightforward. As we've added more use cases, we've improved import performance, and generalized the tools. Common tasks include creating IDs, and mapping attribute values to/from IDs. Recent work improved support for ID/value mapping, backed by [LevelDB](https://github.com/google/leveldb).

But, remember this for later: we did not use any application-specific caching. We simply imported the data according to the static schema.

### Hardware

For our SF1000 index, we used a cluster of eight c4.8xlarge nodes on AWS. These machines have 36 vCPUs and 60 GiB of memory each. These are large, compute-optimized machines, although the cluster is notably smaller than the Hortonworks cluster of 10 nodes. Comparing benchmarks across disparate hardware can be tricky, but we're proud of the results we saw, no matter what metric is used.

Here's a more detailed hardware comparison:

|              | Pilosa          | Druid                  |
|--------------|-----------------|------------------------|
| CPU          | 288 cores       | 320 cores              |
| Host Type    | virtual (AWS)   | physical               |
| Cluster Size | 8 nodes         | 10 nodes               |
| Memory       | 60GB RAM/node   | 256GB RAM/node         |
| Disk         | 80GB EBS Volume | 6x 4TB SCSI disks/node |

## Queries

Just as the SSB schema was modified from TPC-H, so were the queries. Not all TPC-H queries translated to the new schema, so a new set of four flights of three or four queries each was described. The queries in each flight are similar in structure and dimensionality, but sometimes highly variable in selectivity.

Flight 1 (Q1.x) sums revenue over a time range, a range of discount values, and a range of quantity values, then simply lists the results. In SQL, Q1.1 looks like this:

```sql
select sum(lo_extendedprice*lo_discount) as revenue
from lineorder, date
where lo_orderdate = d_datekey
and d_year = 1993
and lo_discount between1 and 3
and lo_quantity < 25;
 ```

The same query in Pilosa:

```pql
Sum(
	Intersect(
		Bitmap(frame=lo_year, rowID=1993),
		Range(frame=lo_discount, lo_discount >= 1),
		Range(frame=lo_discount, lo_discount <= 3),
		Range(frame=lo_quantity, lo_quantity < 25)
	),
frame=lo_revenue_computed, field=lo_revenue_computed)
```

There are two things to note here: 

- `lo_discount >= 1` and similar clauses, the syntax for integer [range queries](/docs/latest/query-language/#range-bsi) on [BSI](/docs/latest/data-model/#bsi-range-encoding) fields. 
- `Sum(<bitmap>, frame=<frame>, field=<field>)`, the syntax for integer [summation](/docs/latest/query-language/#sum) on BSI fields.

In the context of the Pilosa data model, the Q1.x queries produce zero-dimensional results - a single scalar value. This means they can be computed directly with a single Pilosa query. All other SSB flights involve grouping and ordering, which increases the dimensionality of the results, requiring multiple independent Pilosa queries. This is a qualitative difference that demonstrates Pilosa usage well, so let's look at one more query.

{{< note title="Note" >}}

Note that Pilosa does support one-dimensional sorted results in many situations via the <code>TopN</code> query - as explored in [the transportation use case](/use-cases/taming-transportation-data/) - but the BSI <code>Sum</code> query is not currently compatible with <code>TopN</code>.

{{< /note >}}

Flight 2 sums revenue over a time range, and a range of brands. The results are grouped by (year, brand). In SQL:

```sql
select sum(lo_revenue), d_year, p_brand1
from lineorder, date, part, supplier
where lo_orderdate = d_datekey
and lo_partkey = p_partkey
and lo_suppkey = s_suppkey
and p_category = 'MFGR#12'
and s_region = 'AMERICA'
group by d_year, p_brand1
order by d_year, p_brand1;
```

One way to accomplish this in Pilosa is with this query template:

```pql
Sum(
	Intersect(
		Bitmap(frame=p_brand1, rowID=<BRAND>),
		Bitmap(frame=lo_year, rowID=<YEAR>),
		Bitmap(frame=s_region, rowID=0),
	),
	frame=lo_revenue, field=lo_revenue)
```

Note the `<BRAND>` and `<YEAR>` placeholders (the `p_category = 'MFGR#12'` clause is equivalent to selecting a certain set of brands). We need the sum for each (year, brand) combination, and the `Sum` query does not perform any grouping itself. Instead, in our application, we run one query for each (year, brand) pair. In case you're not familiar with the SSB details, this means we iterate this Pilosa query over seven years, and 40 brands, for a total of 280 queries.

280 queries, to produce results that are described by one SQL query! That might sound odd, but this is where Pilosa really shines: we can run many of them concurrently, and **every** CPU on the cluster will be fully utilized until the queryset finishes. It finishes very quickly, even with many nested operations, and then we can move on to the next queryset. Our results are clear: running all those queries is no problem.

Q3.x and Q4.x have different structure, but they are not especially complicated or surprising. Their queries tend to both produce results of higher dimensionality, and require more iterations, but they're still no challenge for Pilosa.

One last point: the order of those `Bitmap` queries inside an `Intersect` can have a meaningful impact on query speed. We set them up in the correct order manually, but it wasn't a guessing game; we followed some simple, clear rules to decide. When we have a query planner, this will be transparent.

### Results

Here are the final numbers:

![Pilosa vs Druid results](/img/retail-analytics/results-comparison.png)
*Pilosa vs Druid results, Scale Factor 1000*

| Query | Pilosa | Druid |
|-------|--------|-------|
|   1.1 |   .669 | 0.782 |
|   1.2 |   .486 | 0.673 |
|   1.3 |   .505 | 0.853 |
|   2.1 |  1.562 |  1.08 |
|   2.2 |  .3666 |  2.69 |
|   2.3 |  .0699 | 0.577 |
|   3.1 |  1.453 |   1.5 |
|   3.2 |  1.335 | 0.673 |
|   3.3 |   .154 | 0.481 |
|   3.4 |  .0236 | 0.769 |
|   4.1 |  1.082 | 0.994 |
|   4.2 |  1.170 | 0.731 |
|   4.3 |  1.934 | 0.635 |

We can summarize with an average of all 13 query times: Pilosa clocks in at 831ms, compared to Druid's 960ms. 

Again, it's important to point out that there is no application-specific caching in use here. After importing the data according to the static schema, all queries are ad-hoc. Q2.3 and Q3.4 are so fast, 70ms and 27ms, that you might assume otherwise. Actually, these queries are just great demonstrations of Pilosa's original use-case of individual, ad-hoc queries on huge data sets.

You'll notice Pilosa tends to slow down on the high-iteration queries: 2.1, 3.2, 4.3. This is expected; for a given query, when CPUs are saturated, all we can do is throw more hardware at the problem. However, in some cases there are smarter ways to build these queries, that can drastically cut back on the number of iterations necessary. For example, using the equivalent of a `LIMIT 100` can allow the application to use some heuristics to discard much of the tail end of the result rows - *before* the queries happen. 

The queries were run with a small [demo app](https://github.com/pilosa/demo-ssb), which defines a group of Pilosa queries for each SSB query, runs them with appropriate batching/concurrency settings, and collates the results and benchmark times.

{{< note title="Note" >}}
Note that, as in the Druid benchmark, sorting of results is not included. The effect should be negligible especially for the lower-iteration queries; even the largest result set of 800 rows can be sorted during post-processing or display with almost no overhead.
{{< /note >}}

We're very proud of Pilosa's performance, those numbers are extremely competitive. But the final numbers hide all of the effort that went into them. If you're interested in that story, be sure to keep up with our blog, where an upcoming post will go into excruciating technical detail.

### References
[Hortonworks inspiration](https://hortonworks.com/blog/sub-second-analytics-hive-druid/)

[SSB description](https://www.cs.umb.edu/~poneil/StarSchemaB.PDF)

[ssb-dbgen](https://github.com/electrum/ssb-dbgen)

[PDK](https://github.com/pilosa/pdk) for ingest

[Demo app](https://github.com/pilosa/demo-ssb) for querying

[Pilosa repo](https://github.com/pilosa/pilosa)

[Pilosa docs](https://www.pilosa.com/docs/)
