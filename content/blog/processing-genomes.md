+++
date = "2018-05-01"
publishdate = "2018-05-11"
title = "How to Process Human Genomes in Pilosa"
author = "Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/processing-genomes/banner.jpg"
overlay_color = "blue" # blue, green, or light
+++

We have found interesting results exploring genomics with Pilosa in the past. Recently, we challenged ourselves to index a large number of full human genomes in order to see how fast Pilosa queries run on that sort of data.

<!--more-->

### A Crash Course in Genome Sequencing

A genome is just a really long string, how difficult could it be to model it? As it turns out, the situation is quite a bit more nuanced. We don't claim to have deep expertise in this domain, but after some background research, we have found a point in the sequencing pipeline where connecting to Pilosa provides some real value.

A human genome consists of approximately 3 billion DNA base pairs. For a given sample, each of these is, naively, exactly one nucleotide, `A`, `T`, `G` or `C`, representable with one character (or two bits), at one precisely specified coordinate. When sequencing a genome, things get a little more fuzzy. To start with, the data coming out of a sequencer isn't "just a really long string". It's [hundreds of gigs](https://medium.com/precision-medicine/how-big-is-the-human-genome-e90caa3409b0) of short reads with corresponding metadata. After some processing, that same sample might be represented as a VCF file, representing the variants (mutations) relative to a reference genome. 

If a sequenced genome is stored as, more or less, a "diff" based on a reference genome, how is the reference stored? Data is available in many formats, but we chose to use the Genome Reference Consortium Human Build 37 (GRCh37) in FASTA format. This format is, ideally, very close to the "really long string" representation of a genome. A file has several sections, each of which might contain the series of `A`, `T`, `G`, `C`, at precisely-known offsets, for an entire chromosome. However, the format supports more than this: `N`, which represents *any* nucleotide, and `-`, for a "gap of indeterminate length". The reference file is very clean: almost entirely `ATGC`, and a small number of `N`s.

An early idea was to find a source of many real human genomes which we could index. Once we fully appreciated the complexity here, we settled on a simpler proof-of-concept approach. After indexing the clean GRCh37 file, we simply generated additional genomes, as needed, by randomly mutating a small fraction of the nucleotides. This minimized our overhead required in finding data, matching reference versions, and understanding more file formats. We made some simplifying assumptions: uniformly distributed mutations at a rate between 0.1% and 0.5%, and problems with alignment or variant confidence. This allowed us to work with some representative data, to explore queries and measure performance.

### Genomes as Bitmaps

Pilosa stores everything as ones and zeros, in an index that can easily scale in both rows and columns. What is a sensible way to represent a genome, given this giant binary matrix? Of course, the answer depends on what you want to do with the index. We had tried two approaches in the past:

* One genome per column, each row representing a different nucleotide [helix].
* One genome per row, each column representing a [k-mer](https://en.wikipedia.org/wiki/K-mer) match to a reference genome.

The genome-per-column model matches Pilosa's original design, with columns as records, and rows as attributes. However, it has scaling issues. The k-mer model works very well, but only stores the k-mer matches, not the genomes themselves. We want something that's both general and scalable.

With the experience gained from these two approaches, plus some expert advice from [Gareth](https://twitter.com/gareth862), we settled on a new model: each row is a genome, and each nucelotide is stored in a group of four columns. For example, using a reference genome that begins `GTAA`, and another genome that begins `GTTA`, one tiny corner of our index will look like this:

![Genome model simple](/img/blog/processing-genomes/genome-model-simple.png)
*Genome data model*

With 3 billion base pairs, we end up with 12 billion columns, and one row per sample. The combination of index width and [`sliceWidth`](../docs/glossary/#slicewidth) affects parallel performance, as well as the number of open files. We took this opportunity to experiment with the `sliceWidth` and found that increasing from our default size of 2<sup>20</sup> to 2<sup>24</sup> was a good balance.

Sequenced genomes are the main entity in the index, but we can do more than that! For example, base pairs on chromosome 1 are all stored in the first billion or so columns (chromosome 1 is about 250M base pairs long). We can store a special "mask" bitmap that is all ones for those columns, and zero elsewhere. Do this for each of the 25 chromosomes (1-22, X, Y, and mitochondrial), and you gain the ability to select only base pairs on a given chromosome. Similarly, any gene that lives in a known region on a chromosome can be given a mask bitmap.

![Genome model details](/img/blog/processing-genomes/genome-model-details.png)
*More genome bitmap tricks*

#### Now what?

With this more general data model, some interesting queries become possible:

1. How similar are two people genetically? Pilosa allows for a number of comparison metrics here. Perhaps the simplest is a count of how many base pairs they share: `Count(Intersect())`. Any [binary similarity metric](http://www.iiisci.org/journal/CV$/sci/pdfs/GS315JG.pdf) is also easy to compute by combining a small number of Pilosa queries. With the "mask" bitmaps shown above, it is trivial to run similar comparison queries restricted to specific chromosomes or genes.

2. TopN: Which genomes are most similar to a particular genome? This might be used to identify people who are likely to have a disease, or certain disposition.

3. Identifying families and relations: a search could find cliques of individuals, *without* a starting genome.

#### Performance

With speed as a main goal, we spun up a 720-core cluster with 1.2TB of RAM (20 x c4.8xlarge, 60Gb RAM, 36 vCPU). We started ingesting new data on this cluster at a rate of less than 15 seconds per genome, or 216M SetBits (nucleotides) per second. This is already plenty fast, but there are clear paths to improve this. We built our import around the FASTA format, but with VCF files, we can run imports that only need to set one bit per variant, rather than one per base pair. This would be partly enabled by restructuring the index to group all base pairs on the reference genome together.

With hundreds of genomes imported into this index, we were finally able to run some queries. Comparing two genomes, as in query #1 above, takes about 150 milliseconds. Query #2, identifying the most similar genomes to a given one, across the entire index, completes in just seconds. The best part? This scales to a large number of rows, allowing much faster queries across many more genomes.

The work is ongoing, and you can follow new developments in the import process in the [PDK repo](https://github.com/pilosa/pdk/tree/genome/usecase/genome).

----

Banner image by the original authors of the Protein Data Bank (PDB) structural data and open-source chemical structure viewer Jmol, CC BY-SA 3.0, https://commons.wikimedia.org/w/index.php?curid=21983632

_Alan is a software engineer at Pilosa. When he’s not mapping the universe, you can find him playing with laser cutters, building fidget spinners for his dog, or practicing his sick photography skills. Find him on Twitter [@gsnark](https://twitter.com/gsnark)._
