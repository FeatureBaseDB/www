+++
title = "Glossary"
+++

# Glossary

**Column:** Columns are the fundamental horizontal data axis within Pilosa.  Columns are global to all Frames within a DB.

**Row:** Rows are the fundamental vertical data axis within Pilosa.  They are namespaced to each Frame within a DB.

**Bit:** A bit is the intersection of a Row and Column

**Bitmap:** The on-disk and in-memory representation of a Row.

**Roaring Bitmap:** This is the compressed bitmap format which Pilosa uses.
 http://roaringbitmap.org

**Attribute:** Attributes can be associated to both rows and columns.  This metadata is kept separately from the core binary matrix in a BoltDB store.

**PQL:** Pilosa Query Language

**Frame:** Frames are used to segment rows into different categories - row ids are namespaced by frame such that the same row id in a different frame refers to a different row. For Ranked frames, rows are kept in sorted order within the frame. 

**View:** Views separate the different data layouts within a Frame. The two primary views are Standard and Inverse which represent the typical row/column data and its inverse respectively. Time based Frame Views are automatically generated for each time quantum. Views are internally managed by Pilosa, and never exposed directly via the API. This simplifies the functional interface by separating it from the physical data representation.

**Fragment:** A Fragment is the intersection of a frame and slice in an index.

**Slice:** Columns are sharded on a preset width. Each shard is referred to as a Slice in Pilosa. Slices are operated on in parallel and are evenly distributed across the cluster via a consistent hash.

**SliceWidth:** This is the default number of columns in a slice.

**MaxSlice:** The total number of slices allocated to handle current set of columns.  This value is important for all nodes to efficiently distribute queries.

**Anti-entropy:** A periodic process that compares each slice and its replicas across the cluster to repair inconsistencies.

**Node:** An individual running instance of Pilosa server which belongs to a cluster.  

**Cluster:** A cluster consists of one or more nodes which share a cluster configuration. The cluster also defines how data is replicated throughout and how internode communication is coordinated. Pilosa does not have a leader node, all data is evenly distributed, and any node can respond to queries.

**TopN:** Given a Frame and/or RowID this query returns the ordered set of RowID's by the number of columns that have a bit set in that row.

**Tanimoto:** Used for similarity queries on Pilosa data. The Tanimoto Coefficient is the ratio of the intersecting set to the union set as the measure of similarity. 

**Protobuf:**: ?

**TOML:** We use TOML for our configuration file format. https://github.com/toml-lang/toml

**Jump Consistent Hash:** A fast, minimal memory, consistent hash algorithm that evenly distributes the workload even when the number of buckets changes.
https://arxiv.org/pdf/1406.2294v1.pdf

**Partition:** The consistent hash is compiled with a maximum number of partitions or locations on the unit circle that keys are mapped to. Partitions are then evenly mapped to physical nodes. To add nodes to the cluster you simply need to remap the partitions, and associated data across the new cluster topography.

**Replica:** A copy of a [fragment] on a different host from the original. The "cluster.replicas" configuration parameter determines how many replicas of a fragment exist in the cluster (including the original, so a value of 1 means no extra copies are made).
