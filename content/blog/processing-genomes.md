+++
date = "2018-05-01"
publishdate = "2018-05-11"
title = "Genome Comparisons in 4 Milliseconds"
author = "Alan Bernstein and Matt Jaffee"
author_img = "2"
image = "/img/blog/processing-genomes/banner.jpg"
overlay_color = "blue" # blue, green, or light
+++


6 Gigabits. That's about how much data is encoded in your DNA. That may sound like a lot, or a little depending on your comfort level, but with 7 billion humans on the planet, that we're in "big data" territory is undeniable. Can we bend Pilosa to a problem of this mind boggling size? How fast can we compare two genomes? Or two thousand? What about finding groups of related individuals, or certain disease markers? How do you even represent this kind of data as a binary matrix? Let's take a look...


<!--more-->

### A Crash Course in Genome Sequencing

A genome is just a set of 23 pairs of really long strings, how difficult could it be to model it? As it turns out, the situation is quite a bit more nuanced. 

A human genome consists of approximately 3 billion base pairs. For a given sample, each of these is, naively, representable as single characters `A`, `T`, `G` or `C`, at one precisely specified coordinate in the genome. When sequencing a genome, things get a little more fuzzy. To start with, the data coming out of a sequencer isn't just a series of strings. It's [hundreds of gigs](https://medium.com/precision-medicine/how-big-is-the-human-genome-e90caa3409b0) of short reads with corresponding metadata. After some processing, that same sample might be represented as a VCF file, showing the variants (mutations) relative to a reference genome.

If a sequenced genome is stored as, more or less, a "diff" based on a reference genome, how is the reference stored? Data is available in many formats, but we chose to use the Genome Reference Consortium Human Build 37 (GRCh37) in FASTA format. This format is, ideally, very close to the "really long string" representation of a genome. A FASTA file has several sections, each of which might contain the series of `A`, `T`, `G`, `C`, at precisely-known offsets, for an entire chromosome. However, the format supports more than this: `N`, which represents *any* nucleotide, `-`, for a "gap of indeterminate length", and various other characters which represent combinations of multiple bases. These other characters are useful for representing heterozygosity (among other things) where each of the chromosomes in a pair might have a different base at a particular position.  The reference file is very clean: almost entirely `ATGC`, and a small number of `N`s.

For our proof of concept, instead of trying to find real genome data for thousands of individuals, (which might have some privacy issues), we simply generated additional genomes by randomly mutating the GRCh37 reference genome. Each generated genome would contain between 0.1% and 0.5% mutations uniformly distributed in the reference. For this test, we sidestepped problems with alignment or variant confidence; this allowed us to work with some representative data to explore queries and measure performance.

### Genomes as Bitmaps

Let's revisit the basic Pilosa data model:

![Pilosa data model](/img/docs/data-model.svg)
*Pilosa data model*

Pilosa stores relationships as ones and zeros in an index that can easily scale in both rows and columns, and performs operations across rows. Given this giant binary matrix, what is a sensible way to represent a genome? Of course, the answer depends on what you want to do with the index. We had tried two approaches in the past:

1) One genome per column, each row representing a different nucleotide.

 This matches many Pilosa use cases, with columns as records, and rows as attributes. However, it is very awkward to handle, even for just a few genomes because each node in the cluster needs to know about all the rows. As more genomes are added, it can scale very well, but it has a lot of overhead at the outset and requires high memory machines even for small tests. Although each row only represents a single position on the genome, the internal memory needed to track each row is around 100 bytes. This doesn't sound like much, but if you have 1 billion rows, that means you need 100GB of memory!

2) One genome per row, each column representing a [k-mer](https://en.wikipedia.org/wiki/K-mer) match to a sample genome.

![K-mer data model](/img/blog/processing-genomes/kmer-model.png)
*K-mer data model*

The k-mer model works very well, but only stores the k-mer matches, not the genomes themselves. We want something that's both general and scalable.

With the experience gained from these two approaches, plus some expert advice from [Gareth](https://twitter.com/gareth862), we settled on a new model. Pilosa is unique in that it can support extremely wide bitmaps. While most libraries and indexes won't natively support bitmaps for integers larger than 32 bits, Pilosa's custom [roaring](https://roaringbitmap.org/) implementation supports 64 bit integers. This means that we can scale columns effectively forever (2<sup>64</sup> is really big). Pilosa also supports embarrassingly scalable bitmap operations as the number of columns grows, so we decided to use this to our advantage. We simply indexed each entire genome in a single bitmap!

In other words, each row is a genome, and columns represent base pairs at specific positions in the genome. Specifically, each base pair is represented as a group of four columns, one each for `A`, `T`, `G` and `C`. For most positions on the genome, one of those four columns is set. In the heterozygous case, we can simply set multiple bits.

For example, using a reference genome that begins `GTAA`, and another genome that begins `GTTA`, one tiny corner of our index will look like this:

![Genome model simple](/img/blog/processing-genomes/genome-model-simple.png)
*Genome data model*

With 3 billion base pairs, we end up with 12 billion columns, and one row per sample. In Pilosa, the combination of index width and [`shard width`](/docs/glossary/#shardwidth) affects parallel performance, as well as the number of open files. We took this opportunity to experiment with the slice width and found that increasing from our default size of 2<sup>20</sup> to 2<sup>23</sup> was a good balance.

Sequenced genomes are the main entity in the index, but we can do more than that! For example, base pairs on chromosome 1 are all stored in the first billion or so columns (chromosome 1 is about 250M base pairs long). We can store a special "mask" bitmap that is all ones for those columns, and zero elsewhere. Do this for each of the 25 chromosomes (1-22, X, Y, and mitochondrial), and you gain the ability to select only base pairs on a given chromosome. Similarly, any gene that lives in a known region on a chromosome can be given a mask bitmap.

Up to this point we have been describing DNA as one long string of data, but in reality DNA is tightly wrapped and compacted around nucleosomes. The specifics of this compacting allow for each cell type to have different characteristics by "opening" and "closing" specific portions of the DNA. We can use "cell type masks" to represent which regions of the genome are "open" in each cell type, allowing us to compare different tissue types against each other (such as normal and cancerous tissue) to understand how changes in the DNA landscape might be contributing to disease!

![Genome model details](/img/blog/processing-genomes/genome-model-details.png)
*More genome bitmap tricks*

#### Now what?

With this more general data model, some interesting queries become possible:

1. How similar are two people genetically? Pilosa allows for a number of comparison metrics here. Perhaps the simplest is a count of how many base pairs they share: `Count(Intersect())`. Any [binary similarity metric](http://www.iiisci.org/journal/CV$/sci/pdfs/GS315JG.pdf) is also easy to compute by combining a small number of Pilosa queries. With the "mask" bitmaps shown above, it is trivial to run similar comparison queries restricted to specific chromosomes or genes.

2. TopN: Which genomes are most similar to a particular genome? This might be used to identify people who are likely to have a disease, or certain disposition. A one-to-many comparison search on [GEDMatch](https://www.gedmatch.com) was recently used to match a suspect in a decades-old [serial killer case](https://www.washingtonpost.com/local/public-safety/to-find-alleged-golden-state-killer-investigators-first-found-his-great-great-great-grandparents/2018/04/30/3c865fe7-dfcc-4a0e-b6b2-0bec548d501f_story.html?utm_term=.87045d490fd3). Perhaps there is an opportunity to speed up that kind of computation with Pilosa?

3. Identifying families and relations: a search could find cliques of individuals, *without* a starting genome.

#### Performance

With speed as a main goal, we spun up a 360-core cluster with 600GB of total RAM (10 x c4.8xlarge, 60GB RAM, 36 vCPU). Because we know ahead of time which Pilosa column each position on the genome maps to, we were able to parallelize the ingestion of each genome based on Pilosa's shard width. Basically we cut each genome into portions that corresponded to 2<sup>23</sup> Pilosa columns, and gave each portion to a separate CPU core to process and send to Pilosa. Both client and cluster side, the ingestion was totally parallel.

We were able to ingest new genomes on this cluster at a rate of less than 15 seconds each, or 216M SetBits (nucleotides) per second. This is already plenty fast, but there are several obvious improvements that could be made. Specifically, we built our import around the FASTA format, but with VCF files, we can run imports that only need to set one bit per variant, rather than one per base pair. Our import protocol is also built around specifying each bit as a row/column pair, but for this use case, we could specify the row once and then all the columns that need to be set, saving a ton of bandwith.

<center>
{{< tweet 991387773587337217 >}}
</center>
(we also did some experiments on a 20-node cluster)


With hundreds of genomes imported into this index, we were finally able to run some queries. Comparing two genomes, as in query #1 above, takes about 150 milliseconds. Query #2, identifying the most similar genomes to a given one, across the entire index, completes in just seconds. The best part? This scales to a large number of rows, allowing much faster queries across many more genomes.

OK, but... 4 milliseconds? Where's that come from? We performed the following query `TopN(Difference(Bitmap(frame=sequences, row=1), Bitmap(frame=sequences, row=0)), frame=sequences)`. This is subtracting the reference genome from Person 1's genome to get all the places where Person 1 varies from the reference, and then using that as a filter to a TopN query. The result is a list of genomes ordered by the number of variants they have in common with Person 1. This query takes about 260ms on our cluster with 29 genomes loaded + the reference. 260ms/29 equals about 9ms per genome. We then loaded 100 genomes and ran the same query - the median run time was about 400ms or 4ms per genome! Upping the ante, we loaded 200 genomes - this time the median was 1.2s giving us about 6ms per genome. Interestingly, the minimum time we observed for this query was a fairly astounding 554ms which gives us hope that with some refinement, we may be able to process genome comparisons in under 3ms consistently.

The work is ongoing, and you can follow new developments in the import process in the [PDK repo](https://github.com/pilosa/pdk/tree/genome/usecase/genome). If you are conducting genomics research that you'd like to discuss with our team, please don't hesitate to reach out to [info@pilosa.com](mailto:info@pilosa.com). We're excited to continue making advancements in this space!

----

Banner image by the original authors of the Protein Data Bank (PDB) structural data and open-source chemical structure viewer Jmol, CC BY-SA 3.0, https://commons.wikimedia.org/w/index.php?curid=21983632

_Alan is a software engineer at Pilosa. When he’s not mapping the universe, you can find him playing with laser cutters, building fidget spinners for his dog, or practicing his sick photography skills. Find him on Twitter [@gsnark](https://twitter.com/gsnark)._

_Jaffee is a lead software engineer at Pilosa. When he’s not dabbling in bioinformatics, he enjoys jiu-jitsu, building mechanical keyboards, and spending time with family. Follow him on Twitter at [@mattjaffee](https://twitter.com/mattjaffee?lang=en)._
