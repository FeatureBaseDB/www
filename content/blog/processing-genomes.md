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

If a sequenced genome is stored as, more or less, a "diff" based on a reference genome, how is the reference stored? Data is available in many formats, but we chose to use the Genome Reference Consortium Human Build 37 (GRCh37) in FASTA format. This format is, ideally, very close to the "really long string" representation of a genome. A file has several sections, each of which might contain the series of `A`, `T`, `G`, `C`, at precisely-known offsets, for an entire chromosome. However, the format supports more than this: `N`, which represents *any* nucleotide, `-`, for a "gap of indeterminate length", and various other characters which represent combinations of multiple bases. These other characters are useful for representing heterozygousity (among other things) where each of the chromosomes in a pair might have a different base at a particular position.  The reference file is very clean: almost entirely `ATGC`, and a small number of `N`s.

An early idea was to find a source of many real human genomes which we could index. Once we fully appreciated the complexity here, we settled on a simpler proof-of-concept approach. After indexing the clean GRCh37 file, we simply generated additional genomes, as needed, by randomly mutating a small fraction of the nucleotides. This minimized our overhead required in finding data, matching reference versions, and understanding more file formats. We made some simplifying assumptions: uniformly distributed mutations at a rate between 0.1% and 0.5%, and no problems with alignment or variant confidence. This allowed us to work with some representative data, to explore queries and measure performance.

### Genomes as Bitmaps

Pilosa stores everything as ones and zeros, in an index that can easily scale in both rows and columns. What is a sensible way to represent a genome, given this giant binary matrix? Of course, the answer depends on what you want to do with the index. We had tried two approaches in the past:

* One genome per column, each row representing a different nucleotide [helix].
* One genome per row, each column representing a [k-mer](https://en.wikipedia.org/wiki/K-mer) match to a reference genome.

The genome-per-column model matches Pilosa's original design, with columns as records, and rows as attributes. However, it is very awkward to handle, even for just a few genomes because each node in the cluster needs to know about all the rows. As more genomes are added, it can scale very well, but it has a lot of overhead at the outset and requires high memory machines even for small tests. Although each row only represents a single position on the genome, the internal memory needed to track each row is around 100 bytes. This doesn't sound like much, but if you have 1 billion rows, that means you need 100GB of memory!

The k-mer model works very well, but only stores the k-mer matches, not the genomes themselves. We want something that's both general and scalable.

With the experience gained from these two approaches, plus some expert advice from [Gareth](https://twitter.com/gareth862), we settled on a new model. Pilosa is unique in that it can support extremely wide bitmaps. While most libraries and indexes won't natively support bitmaps for integers larger than 32 bits, Pilosa's custom [roaring](https://roaringbitmap.org/) implementation supports 64 bit integers. This means that we can scale columns effectively forever (2<sup>64</sup> is really big). Pilosa also supports embarrassingly scalable bitmap operations as the number of columns grows, so we decided to use this to our advantage. We simply indexed each entire genome in a single bitmap!

In other words, each row is a genome, and columns represent base pairs at specific positions in the genome. Specifically, each base pair is represented as a group of four columns, one each for `A`, `T`, `G` and `C`. For most positions on the genome, one of those four columns is set. In the heterozygous case, we can simply set multiple bits.

For example, using a reference genome that begins `GTAA`, and another genome that begins `GTTA`, one tiny corner of our index will look like this:

![Genome model simple](/img/blog/processing-genomes/genome-model-simple.png)
*Genome data model*

With 3 billion base pairs, we end up with 12 billion columns, and one row per sample. The combination of index width and [`slice width`](../docs/glossary/#slicewidth) affects parallel performance, as well as the number of open files. We took this opportunity to experiment with the slice width and found that increasing from our default size of 2<sup>20</sup> to 2<sup>23</sup> was a good balance.

Sequenced genomes are the main entity in the index, but we can do more than that! For example, base pairs on chromosome 1 are all stored in the first billion or so columns (chromosome 1 is about 250M base pairs long). We can store a special "mask" bitmap that is all ones for those columns, and zero elsewhere. Do this for each of the 25 chromosomes (1-22, X, Y, and mitochondrial), and you gain the ability to select only base pairs on a given chromosome. Similarly, any gene that lives in a known region on a chromosome can be given a mask bitmap.

Masks are even more useful if you go slightly deeper into the biology. While we're thinking now of DNA as one long string of data, in reality it is all folded up and twisted in different ways within different types of cells. This folding means that only certain parts of the DNA are available for transcription in certain cells. With masks, we can represent which parts of the genome are available for transcription in different cells!

![Genome model details](/img/blog/processing-genomes/genome-model-details.png)
*More genome bitmap tricks*

#### Now what?

With this more general data model, some interesting queries become possible:

1. How similar are two people genetically? Pilosa allows for a number of comparison metrics here. Perhaps the simplest is a count of how many base pairs they share: `Count(Intersect())`. Any [binary similarity metric](http://www.iiisci.org/journal/CV$/sci/pdfs/GS315JG.pdf) is also easy to compute by combining a small number of Pilosa queries. With the "mask" bitmaps shown above, it is trivial to run similar comparison queries restricted to specific chromosomes or genes.

2. TopN: Which genomes are most similar to a particular genome? This might be used to identify people who are likely to have a disease, or certain disposition. A one-to-many comparison search on [GEDMatch](https://www.gedmatch.com) was recently used to match a suspect in a decades-old [serial killer case](https://www.washingtonpost.com/local/public-safety/to-find-alleged-golden-state-killer-investigators-first-found-his-great-great-great-grandparents/2018/04/30/3c865fe7-dfcc-4a0e-b6b2-0bec548d501f_story.html?utm_term=.87045d490fd3). Perhaps there is an opportunity to speed up that kind of computation with Pilosa?

3. Identifying families and relations: a search could find cliques of individuals, *without* a starting genome.

#### Performance

With speed as a main goal, we spun up a 360-core cluster with 600GB of total RAM (10 x c4.8xlarge, 60GB RAM, 36 vCPU). We started ingesting new data on this cluster at a rate of less than 15 seconds per genome, or 216M SetBits (nucleotides) per second. This is already plenty fast, but there are clear paths to improve this. We built our import around the FASTA format, but with VCF files, we can run imports that only need to set one bit per variant, rather than one per base pair. This would be partly enabled by restructuring the index to group all base pairs on the reference genome together.

<center>
{{< tweet 991387773587337217 >}}
</center>
(we also did some experiments on a 20-node cluster)


With hundreds of genomes imported into this index, we were finally able to run some queries. Comparing two genomes, as in query #1 above, takes about 150 milliseconds. Query #2, identifying the most similar genomes to a given one, across the entire index, completes in just seconds. The best part? This scales to a large number of rows, allowing much faster queries across many more genomes.

The work is ongoing, and you can follow new developments in the import process in the [PDK repo](https://github.com/pilosa/pdk/tree/genome/usecase/genome). If you are conducting genomics research that you'd like to discuss with our team, please don't hesitate to reach out to [info@pilosa.com](mailto:info@pilosa.com). We're excited to continue making advancements in this space!

----

Banner image by the original authors of the Protein Data Bank (PDB) structural data and open-source chemical structure viewer Jmol, CC BY-SA 3.0, https://commons.wikimedia.org/w/index.php?curid=21983632

_Alan is a software engineer at Pilosa. When he’s not mapping the universe, you can find him playing with laser cutters, building fidget spinners for his dog, or practicing his sick photography skills. Find him on Twitter [@gsnark](https://twitter.com/gsnark)._
