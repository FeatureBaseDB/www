+++
date = "2017-02-06T19:12:50-06:00"
title = "Quick Start"
draft = true

menu = "docsGettingStarted"
slug = "quick-start"
weight = 1

+++

# Getting Started

Pilosa supports an HTTP interface which uses JSON by default. 
Any HTTP tool can be used to interact with the Pilosa server. The examples in this documentation will use [curl](https://curl.haxx.se/) which is available by default on many UNIX-like systems including Linux and MacOS. Windows users can download curl [here](https://curl.haxx.se/download.html).

Note that Pilosa server requires a high limit for open files. Check the documentation of your system to see how to increase it in case you hit that limit.

## Starting Pilosa

Follow the steps in the [Install](install) document to install Pilosa.
Execute the following in a terminal to run Pilosa with the default configuration (Pilosa will be available at `localhost:10101`):
```
pilosa server
```

If you are using the Docker image, you can run an ephemeral Pilosa container on the default address using the following command:
```
docker run -it --rm --name pilosa -p 10101:10101 pilosa:latest
```

Let's make sure Pilosa is running:
```
curl localhost:10101/nodes
```

Which should output: `[{"host":":10101"}]`

## Sample Project

In order to better understand Pilosa's capabilities, we will create a sample project called "Star Trace" containing information about the top 1,000 most recently updated Github repositories which have "Austin" in their name. The Star Trace index will include data points such as programming language, tags, and stargazers—people who have starred a project.

Although Pilosa doesn't keep the data in a tabular format, we still use the terms "columns" and "rows" when describing the data model. We put the primary objects in columns, and the properties of those objects in rows. For example, the Star Trace project will contain a database called "repository" which contains columns representing Github repositories, and rows representing properties like programming languages and tags. We can better organize the rows by grouping them into sets called Frames. So our Star Trace project might have a "languages" frame as well as a "tags" frame. You can learn more about databases and frames in the [Data Model](data_model) section of the documentation.

### Create the Schema

Before we can import data or run queries, we need to create the schema for our databases. Let's create the repository database first:
```
$ curl -XPOST localhost:10101/db -d '{"db": "repository", "options": {"columnLabel": "repo_id"}}'
```

Repository IDs are the main focus of the `repository` database, so we chose `repo_id` as the column label.

Let's create the `stargazer` frame which has user IDs of stargazers as its rows:
```
$ curl -XPOST localhost:10101/frame -d '{"db": "repository", "frame": "stargazer", "options": {"rowLabel": "stargazer_id"}}'
```

Since our data contains time stamps for the time users starred repos, we will change the *time quantum* for the `stargazer` frame. Time quantum is the resolution of the time we want to use. We will set it to `YMD` (year, month, day) for `stargazer`:
```
$ curl -XPATCH localhost:10101/frame/time_quantum -d '{"db": "repository", "frame": "stargazer", "time_quantum": "YMD"}'
```

Next up is the `language` frame, which will contain IDs for programming languages:
```
$ curl -XPOST localhost:10101/frame -d '{"db": "repository", "frame": "language", "options": {"rowLabel": "language_id"}}'
```
### Import Some Data

The sample data for the "Star Trace" project is at [Pilosa Getting Started repository](https://github.com/pilosa/getting-started). Download `*.csv` files in that repo and run the following commands to import the data into Pilosa.

If you are running the native compiled version of Pilosa, you can run:
```
pilosa import -d repository -f stargazer repository-stargazer.csv
pilosa import -d repository -f language repository-language.csv
```

If you are using a Docker container for Pilosa (with name `pilosa`), you should instead copy the `*.csv` file into the container and then import them:
```
docker cp repository-stargazer.csv pilosa:/repository-stargazer.csv
docker exec -it pilosa pilosa import -d repository -f stargazer /repository-stargazer.csv
docker cp repository-language.csv pilosa:/repository-language.csv
docker exec -it pilosa pilosa import -d repository -f language /repository-language.csv
```

Note that, both the user IDs and the repository IDs were remapped to sequential integers in the data files, they don't correspond to actual Github IDs anymore. You can check out `language.txt` to see the mapping for languages.

### Make Some Queries

Which repositories did user 8 star:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'Bitmap(frame="stargazer", stargazer_id=8)'
```

What are the top 5 languages in the sample data:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'TopN(frame="language", n=5)'
```

Which repositories were starred by user 8 and 18:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'Intersect(Bitmap(frame="stargazer", stargazer_id=8), Bitmap(frame="stargazer", stargazer_id=18))'
```

Which repositories were starred by user 8 or 18:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'Union(Bitmap(frame="stargazer", stargazer_id=8), Bitmap(frame="stargazer", stargazer_id=18))'
```

Which repositories were starred by user 8 and 18 and also were written in language 1:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'Intersect(Bitmap(frame="stargazer", id=8), Bitmap(frame="stargazer", stargazer_id=18), Bitmap(frame="language", language_id=1))'
```

Set user 99999 as a stargazer for repository 77777:
```
curl -XPOST 'localhost:10101/query?db=repository' -d 'SetBit(frame="stargazer", repo_id=77777, stargazer_id=99999)'
```

## What's Next?

You can jump to [Query Language](query_language) for more details about **PQL**, the query language of Pilosa, or [Tutorials](tutorials) for in-depth tutorials about real world use cases of Pilosa. Check out our small but expanding set of official [Client Libraries](client_libraries).
