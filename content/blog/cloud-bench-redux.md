+++
date = "2019-01-13"
publishdate = "2019-01-15"
title = "Benchmarking Redux"
author = "Matt Jaffee"
author_twitter = "mattjaffee"
author_img = "2"
featured = "true"
image = "/img/blog/cloud-bench-redux/banner.jpg"
overlay_color = "green" # blue, green, or light
+++

_This is a follow-on post to our [previous multi-cloud benchmarks.](../why-oci)_

Previously, we ran a number of [Pilosa](https://github.com/pilosa/pilosa)
specific benchmarks across a variety of configurations of hosts on AWS, Azure,
and Oracle cloud. Our broad strokes conclusions were that AWS was the fastest,
Oracle was the most cost effective, and that while not far behind, Azure didn't
stand out - if you work on Azure (or any other cloud incidentally) and want to
dig into this, we'd *love* to.

We've got a few exciting updates in this second edition:

1. We've added GCP to the mix!
2. After getting some feedback from the OCI team, we changed OS image that we're
   using which provided a pretty good boost in some benchmarks and solved the
   mystery of performance differences between the `VM.Standard2.16` and the
   `BM.Standard2.52` instances.
3. We re-ran the AWS `c5.9xlarge` benchmarks on Amazon Linux to be equitable
   with the Oracle benchmarks.
4. We've updated our
   [tooling](https://github.com/pilosa/infrastructure/tree/terraform/examples)
   to make it significantly easier to add new configurations to our existing
   results on [data.world](https://data.world/jaffee/benchmarks).
   
So, if you'll recall, we had a suite of queries that we ran against Pilosa
clusters configured in each cloud, as well as a set of microbenchmarks that just
ran on one instance of each cluster.

So, without further ado, here is the full set of configurations that we've
benchmarked against.

| Cloud | Instance Type              | Cluster Size | Username |
|-------|---------------------------- |-------------: |----------  |
| AWS   | r5d.12xlarge               |            2 |          |
| OCI   | VM.DenseIO2.16             |            3 |          |
| OCI   | BM.HPC2.36                 |            2 | ubuntu   |
| AWS   | c5.9xlarge                 |            3 |          |
| AWS   | c5.9xlarge                 |            3 | ec2-user |
| OCI   | BM.HPC2.36                 |            2 | opc      |
| GCP   | custom-36-73728-discounted |            3 | ubuntu   |
| OCI   | VM.Standard2.16            |            3 | ubuntu   |
| GCP   | custom-36-73728            |            3 | ubuntu   |
| Azure | F16                        |            6 |          |
| OCI   | BM.Standard2.52            |            1 | ubuntu   |
| Azure | Standard_E64s_v3           |            2 |          |
| Azure | Standard_F32s_v2           |            3 |          |
| OCI   | VM.Standard2.16            |            3 | opc      |
| AWS   | c4.8xlarge                 |            3 |          |
| OCI   | BM.Standard2.52            |            1 | opc      |

There are a few nuances to note here. The username column is indicative of which
OS image the instances were running. If it's "opc" or "ec2-user", then it's
Oracle Linux or Amazon Linux respectively. Otherwise it's Ubuntu. Azure and GCP
didn't seem to have hand curated Linux derivatives and they did have official
Ubuntu images, so we used those.


Let's look first at raw performance for the queries:



_Banner Photo by Victor Rodriguez on Unsplash_
