+++
date = "2017-06-15"
publishdate = "2017-06-15"
title = "Tanimoto & Chemical Similarity with Pilosa"
author = "Linh Vo"
author_twitter = "hailinhvo"
author_img = "1"
image = "/img/blog/tanimoto-and-chemical-similarity-with-pilosa/banner.png"
overlay_color = "green" # blue, green, or light
+++

As we continue to test Pilosa against various types of data (e.g., the [Billion Taxi Ride Dataset](https://www.pilosa.com/blog/billion-taxi-ride-dataset-with-pilosa/)), we decided to turn our next endeavor into a dual-purpose test. Specifically, we decided to test Pilosa against the [Chemical Similarity for ChemBL dataset](https://www.ebi.ac.uk/chembl/downloads) while also testing Pilosa’s ability to run algorithms in its native core.

<!--more-->

The notion of chemical similarity (or molecular similarity) is one of the most important concepts in cheminformatics. It plays an important role in modern approaches to predicting the properties of chemical compounds, designing chemicals with a predefined set of properties and, especially, in conducting drug design studies by screening large databases containing structures of available or potentially available chemicals. 
One commonly used algorithm to calculate these measures of similarity is the Tanimoto algorithm. The resulting Tanimoto coefficient is fingerprint-based, encoding each molecule to a fingerprint “bit” position, with each bit recording the presence (“1”) or absence (“0”) of a fragment in the molecule. Given the binary format, we determined it would be a perfect fit to test against Pilosa.
 
In this post, we’ll look at the problem of finding chemical similarity and how, using Pilosa, we can achieve performance that is 3x faster than existing state-of-the-art systems (see MongoDB, below) and 10x faster than our initial naive Pilosa implementation. As solutions to the chemical similarity search problem have been attempted by other individuals using different technologies (tested on [MongoDB](http://blog.matt-swain.com/post/87093745652/chemical-similarity-search-in-mongodb) by Matt Swan, or on [PostgreSQL] (http://blog.rguha.net/?p=1261) by Rajarshi Guha), we knew we would be able to compare our results to existing solutions.
 
### Overview of Tanimoto
 
The Tanimoto algorithm states that *A* and *B* are sets of fingerprint “bits” within the fingerprints of molecule *A* and molecule *B*. *AB* is defined as the set of common bits of fingerprints of both molecule *A* and *B*. The resulting Tanimoto coefficient (or *T(A,B)*) ranges from 0, when the fingerprints have no bits in common, to 1, when the fingerprints are identical. Thus,

`T(A,B) = (A ∩ B)/(A + B - A ∩ B)`

The chemical similarity problem then becomes, *Given molecule A, find all formulas that have a Tanimoto coefficient greater than a given threshold*. The greater the value of a set threshold, the more similar the molecules are. 
 
### Pilosa

To model data in Pilosa, one must choose what the columns represent and what the rows represent. We chose to let each column represent a bit position ID within the digital fingerprint and each row represent a molecule ID.
 
Pilosa stores information as a series of bits, and in this case one can use RDKit in Python to convert molecules from their SMILES encoding to Morgan fingerprints with 4,096 bits size, which are arrays of “on” bit positions. As a benchmarking measure, we also followed [Matt Swain’s instructions](http://blog.matt-swain.com/post/87093745652/chemical-similarity-search-in-mongodb) to import the same data set into MongoDB with the same Morgan fingerprint size. 
 
We were able create a data model in Pilosa like so:

![Data Modeling](/img/blog/tanimoto-and-chemical-similarity-with-pilosa/data-model.png)

It took 21 minutes to export chembl_id and SMILES from SDF to csv, and took ~3 minutes to import 1,678,343 rows into Pilosa on a MacBook Pro with a 2.8 GHz 2-core Intel Core i7 processor, memory of 16 GB 1600 MHz DDR3, single host cluster.
 
### Naive Approach
 
The first approach we took after successfully loading the data into Pilosa was rather naive. We created a Python script that used a Pilosa client and sent requests to fetch the following values,

 * Count of *A*

 * Intersection *A ∩ B*

 * Count of *B*
 
The last two requests are batched requests for 100,000 rows. We then calculated the Tanimoto coefficient on the client. 
 
While this approach is simple, its performance is suboptimal due to the network latency required in sending all these requests. Using this setup, Pilosa didn’t compare favorably with MongoDB at all. While we beat MongoDB at lower thresholds, our performance didn't improve much at higher thresholds. MongoDB has an advantage in that its aggregation framework can perform all calculation tasks at the server.
 
![Mongo vs. Pilosa](/img/blog/tanimoto-and-chemical-similarity-with-pilosa/mongo-vs-pilosa1.png)
 
*Chart of comparison between MongoDB aggregation framework and naive Pilosa implementation*
 
### Improved Approach 

However, our naive approach definitely helped us to come up with a better solution. The main problem is network latency, which will be completely resolved if we can perform the Tanimoto algorithm in the Pilosa core. Since Pilosa already stores count of A and B in its own cache, we theorized it would be much faster to calculate Tanimoto inside Pilosa, then return similarity results to a client. 
 
Given the results below, the performance of this approach blew away our naive approach, clocking in at 10x faster. It is also 3x faster than the fastest MongoDB approach. Both used the same molecule, with Morgan fingerprint folded to fixed lengths of 4,096 bits and were run on a MacBook Pro with a 2.8 GHz 2-core Intel Core i7 processor, memory of 16 GB 1600 MHz DDR3, single host cluster

![Mongo vs. Pilosa](/img/blog/tanimoto-and-chemical-similarity-with-pilosa/mongo-vs-pilosa2.png)
 
*Chart of comparison between MongoDB aggregation framework and core Pilosa implementation*

### Conclusion

Even though we improved performance significantly, adding every new algorithm one-by-one into Pilosa’s core isn’t sustainable. Because we want to extend Pilosa’s support of other algorithms, we have implemented a plugin system (which will be released soon!). This will allow for easy and custom development of algorithms that run on Pilosa hosts, thereby cutting the network round trip. Moving Tanimoto to plugin doesn’t change the speed of the similarity calculation that we tested above, and there will be significant room for many other plugin developments without any effect on performance.
