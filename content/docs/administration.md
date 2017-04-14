+++
date = "2017-02-07T17:19:23-06:00"
title = "Administration Guide"
draft = true

menu = "docsAdministration"
slug = "administration-guide"
weight = 7
+++

# Administration Guide

## Installing in production

### Hardware

Pilosa is a standalone, compiled Go application. So there is no need to worry about running and configuring a Java VM. Pilosa can run and very small machines and works well with even medium sized dataset on a personal laptop. If you are reading this section, you are likely ready to deploy a cluster of Pilosa servers handling very large datasets or high velocity data. These are guidelines for running a cluster; specific needs may differ.

### Memory

Pilosa holds all row/column bitmap data in main memory. While this data is compressed more than a typical database, available memory is a primary concern.  In a production environment, we recommend choosing hardware with a large amount of memory >= 64GB.  Prefer a small number of hosts with lots of memory per host over a larger number with less memory each. Larger clusters tend to be less efficient overall due to increased inter-node communication.

### CPUs

Pilosa is a concurrent application written in Go and can take full advantage of multicore machines.

### Disk

Even though the main dataset is in memory Pilosa does back up to disk frequently.  We recommend SSD drives especially if you have a write heavy application.

### Network

Pilosa is designed to be a distributed application, with data replication shared across the cluster.  As such every write and read needs to communicate with several nodes.  Therefore fast internode communication is essential. If using a service like AWS we recommend that all node exist in the same region and availability zone.  The inherent latency of spreading a Pilosa cluster across physical regions it not usually worth the redundancy protection.  Since Pilosa is designed to be an Indexing service there already should be a system of record, or ability to rebuild a Cluster quickly from backups.

### Overview

While pilosa does have some high system requirements it is not a best practice to set up a cluster with the fewest, largest machines available.  You want an evenly distributed load across several nodes in a cluster to easily recover from a single node failure, and have the resource capacity to handle a missing node until it's repaired or replaced.   Nor is it advisable to have many small machines.  The internode network traffic will become a bottleneck.  You can always add nodes later, but that does require some down time.

## Importing and Exporting Data

### Importing

The import API expects a csv of RowID,ColumnID's.

When importing large datasets remember it is much faster to pre sort the data by RowID and then by ColumnID in ascending order. Also, avoid querying pilosa until the import is complete, otherwise you will experience inconsistent results.
```
pilosa import  -d project -f stargazer project-stargazer.csv
```

### Exporting

Exporting Data to csv can be performed on a live instance of pilosa. You need to specify the Database, Frame, and View(default is standard). The API also expects the slice number, but the `pilosa export` sub command will export all slices within a Frame. The data will be in csv format RowID,ColumnID and sorted by column ID.
```
curl --header "Accept: text/csv" "http://localhost:10101/export?db=repository&frame=stargazer&slice=0&view=standard"
```

## Versioning

Pilosa follows Semantic Versioning.[http://semver.org/] 
MAJOR.MINOR.PATCH:

* MAJOR version when you make incompatible API changes,
* MINOR version when you add functionality in a backwards-compatible manner, and
* PATCH version when you make backwards-compatible bug fixes.

### PQL versioning

The Pilosa server should support PQL versioning using HTTP headers. On each request, the client should send a Content-Type header and an Accept header. The server should respond with a Content-Type header that matches the client Accept header. The server should also optionally respond with a Warning header if a PQL version is in a deprecation period, or an HTTP 400 error if a PQL version is no longer supported.

#### Headers

The server should return the Content-Type header matching the client's Accept header:

The Content-Type header should follow this template:
Content-Type: application/vnd.pilosa.pql.v<version>

Version 1 of PQL should send the following request header:
Content-Type: application/vnd.pilosa.pql.v1

The Accept header should follow this template:
Accept: application/vnd.pilosa.json.v<version>

Version 1 of PQL should send the following request header:
Accept: application/vnd.pilosa.json.v1

#### Error handling

Content-Type: application/vnd.pilosa.json.v1
If a PQL version is in a deprecation period, the server responds with a Warning header, as defined in RFC7234, Section 5.5.7. See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Warning

The Warning header should follow the following template:

Warning: 299 pilosa/<pilosa-version> "<Deprecation message>" "<date (RFC7231, Section 7.1.1.1)>"
For example:

Warning: 299 pilosa/2.0 "Deprecated PQL version: PQL v2 will remove support for SetBit() in Pilosa 2.1. Please update your client to support Set() (See https://docs.pilosa.com/pql#versioning)." "Sat, 25 Aug 2017 23:34:45 GMT"
After the deprecation period, the server should reply with an HTTP 400 error, with the deprecation message in the response body.

### Upgrading

When upgrading, upgrade clients first, followed by server for all Minor and Patch level changes.

## Backup/restore

### Data backup

Pilosa continuously writes out the in-memory bitmap data to disk.  This data is organized by DB->Frame->views->Fragment->numbered slice files.  These data files can be routinely backed up to restore nodes in a cluster.

### Backup and restore a node in an existing cluster

Depending on the size of your data you have two options.  For a small dataset you can rely on the periodic anti-entropy sync process to replicate existing data back to this node.

For larger datasets and to make this process faster you could copy the relevant data files from the other nodes to the new one before startup.

Note: This will only work when the replication factor is greater >= 2

#### Using Auto Sync

1. Shutdown the cluster.
2. Modify config file to replace existing node address with new node.
3. Restart all nodes in the cluster
4. Wait for auto sync to replicate data from existing nodes to new node

#### Copying data files

1. To accomplish this goal you will 1st need:
    1. list of all DB on your cluster
    1. list of all frames in your DB's
    1. Max slice per DB (api exists for this)

2. With this information you can query the /fragment/nodes endpoint and iterate over each slice
3. Using the list of slices owned by this node you will then need to manually:
    1. setup a directory structure similar to the other nodes with a path for each DB/frame
    1. copy each owned slice for an existing node to this new node
4. Modify the cluster config file to replace the previous node address with the new node address.
5. Restart the cluster
6. Wait for the 1st sync (10 minutes) to validate db connections