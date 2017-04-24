+++
title = "Data Model"
+++

# Data Model

## Overview

The central component of Pilosa's data model is a boolean matrix. Each cell in the matrix is a single bit - if the bit is set, it indicates that a relationship exists between that particular row and column.

rows and columns can represent anything (they could even represent the same set of things).Pilosa can associate arbitrary key/value pairs (referred to as attributes) to rows and columns, but queries and storage are optimized around the core matrix.

Pilosa lays out data first in rows, so queries which get all the set bits in one or many rows, or compute a combining operation on multiple rows such as Intersect or Union are the fastest. Pilosa also has the ability to categorize rows into different "frames" and quickly retrieve the top rows in a frame sorted by the number of bits set in each row.

Similar to a Graph database Pilosa provides the ability to quickly calculate/compute/analyze/inspect the edge relationships between nodes.  Unlike a graph database the query time does not (some qualifying term) increase as edges cross machine boundaries in a cluster.  The underlying relationship data model is a distributed Roaring bitmap that can horizontally scale (bigly).  

## Index

The purpose of the Index is to represent a data namespace. You cannot perform cross-index queries.  Column-level attributes are global to the Index.

## Column

Column ids are sequential increasing integers and are common to all Frames within a Index.

## Row

Row ids are sequential increasing integers namespaced to each Frame within a Index.

## Frame

Frames are used to segment and define different functional characteristics within your entire index.  You can think of a Frame as a table-like data partition within your Index.

Row-level attributes are namespaced at the Frame level.

## Ranked

Ranked Frames maintain a sorted cache of column counts by Row ID (yielding the top rows by columns with a bit set in each). This cache facilitates the TopN query.  The cache size defaults to 50,000 and can be set at Frame creation.

## LRU

The LRU cache maintains the most recently accessed Rows.

## Time Quantum

The Time Quantum frame aggregates row data into specific time segments such as year, month, day, and hour.

## Attribute

Attributes are arbitrary key/value pairs that can be associated to both rows or columns.  This metadata is stored in a separate BoltDB data structure.

## Slice

Indexes are sharded into groups of columns called Slices - each Slice contains a fixed number of columns which is the SliceWidth.

Columns are sharded on a preset width, and each shard is referred to as a Slice.  Slices are operated on in parallel, and they are evenly distributed across a cluster via a consistent hash algorithm.

## View

Views represent the various data layouts within a Frame. The primary View is called Standard, and it contains the typical Row and Column data. The Inverse View contains the same data with the axes inverted.Time-based Views are automatically generated for each time quantum. Views are internally managed by Pilosa, and never exposed directly via the API. This simplifies the functional interface from the physical data representation.

## Standard

The standard View contains the same Row/Column format as the input data. 

## Inverse

The Inverse View contains the same data with the Row and Column swapped.

## Time Quantums

If a Frame has a time quantum, then Views are generated for each of the defined time segments. For example, a time quantum of YMDH for the date 2006-01-02T15:04:05 would create the following Views with data aggregating into each time segment as it is set:

* standard_2006
* standard_200601
* standard_20060102
* standard_2006010215
