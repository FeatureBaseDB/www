+++
date = "2019-08-13"
publishdate = "2019-08-13"
title = "How to generate an arbitrarily large amount of test data"
author = "Alan Bernstein"
author_twitter = "gsnark"
author_img = "2"
image = "/img/blog/smote/banner.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

Have you ever looked at some publicly available data, and thought, "I wish this data set was 100 times larger"? It seems like there should be an easy way to do that, and it turns out, there is!

<!--more-->

Much of the work we do with [Pilosa](https://www.pilosa.com) involves benchmarking and optimization of data ingestion. With extreme scalability as one of our selling points, using large data sets is crucial. Sample data sets of all kinds are available all over the web, but it isn't always easy to find data sets that are 1) huge, 2) meaningful, 3) well-fit to our target use cases and data models. Often we'll find a great, clean public data set that looks perfect for an experiment, then download it and realize it consists of 100,000 records - not even close to big enough for our purposes.

### Oversampling

Oversampling can save us here. Wikipedia [lists](https://en.wikipedia.org/wiki/Oversampling_and_undersampling_in_data_analysis#Oversampling_techniques_for_classification_problems) only three oversampling methods, starting with random duplication. While duplication would probably do fine for most of our work, it just feels icky to me. Ideally, we could generate realistic samples from the multidimensional distribution underlying the true dataset. A naive way to approach this is to use the marginal distributions - randomly choosing each column value (e.g. from a CSV file) based on the distribution of true values in that column - but this has problems too. Each value would look reasonable by itself, but the relationships between those values wouldn't be realistic (usually). 

As a silly example, a medical data set might have two fields, `heartRate` (numeric) and `alive` (boolean):


 heartRate | alive 
-----------|-------
       180 | true  
         0 | false 
        60 | true  
        90 | true  
         0 | false 
        30 | true  


Analyzing each column, we can approximate its distribution independently of the others. Maybe we'd assume `heartRate` is uniformly distributed between the minimum and maximum values, while `alive` is either true or false, with a probability matching the proportion of true values in the data. Generating values for these independently, you might produce a record with `heartRate=90` and `alive=false`. With some approximation of that full, true distribution, we can avoid this situation. However, estimating such a thing for a CSV file with arbitrary data types, and correlations, seems tricky.

### SMOTE

The other two oversampling methods listed on Wikipedia are variants of [SMOTE](https://arxiv.org/pdf/1106.1813.pdf) (Synthetic Minority Over-sampling TEchnique), an old-fashioned AI algorithm that is deceptively simple, even elegant. SMOTE provides a solution to the correlation problem, without needing to explicitly understand the full distribution. We have taken the core idea of this algorithm, twisted it and abused it, to synthesize silly amounts of test data.

![SMOTE concept](/img/blog/smote/smote-diagram.png)
*Illustration of synthesizing data points in SMOTE. Graphic from a [survey](https://www.jair.org/index.php/jair/article/view/11192) of SMOTE extensions.*

The basic algorithm is described [here](https://www.cs.cmu.edu/afs/cs/project/jair/pub/volume16/chawla02a-html/node6.html). Briefly, an original data point (x<sub>i</sub>, in N-dimensional space **R**<sup>N</sup>) is chosen, one of K [nearest neighbors](https://en.wikipedia.org/wiki/K-nearest_neighbors_algorithm) (x<sub>i3</sub>, for example) is selected, and a random linear combination of those two is produced (r<sub>3</sub>). That's it! Do that, say, 100 times for each data point, and you get a huge oversampling factor, with reasonable computational efficiency. SMOTE takes advantage of the local structure of the dataset to synthesize statistically reasonable data, without explicitly understanding the full correlations.

This works great for real-valued (floating point) data. What if the dataset contains other types, like integers, categorical string values, or even arbitrary text? Although [some variants](https://www.cs.cmu.edu/afs/cs/project/jair/pub/volume16/chawla02a-html/node15.html) handle some of these cases, we had a few other minor modifications in mind.

### Pilosa-SMOTE

The practical goal is to run this algorithm on a wide range of CSV files, which means supporting more data types is important. Supporting integers and categorical values should go a long way, so we started with those. Let's look at the last step of the basic SMOTE algorithm, the random linear combination (r<sub>3</sub>) of the original point x<sub>i</sub>) and the neighbor (x<sub>i3</sub>). We can write this as r<sub>3</sub> = αx<sub>i</sub> + (1-α)x<sub>i3</sub>, where α is a random floating point value. In pseudocode, with a single floating-point value for the data point `x`:

```
neighborIdx = rand.Intn(5)
weight = rand.Float64()
synthetic = weight * x + (1-weight) * neighbors[neighborIdx]
```

Now, if `x` is an integer, this will still produce a floating-point synthetic value. To address this, we simply round the result to the nearest integer. If `x` is categorical (say, one of ten different string values), this doesn't quite work. We could select one of the values based on the random weight, that is:

```
synthetic = x
if weight < 0.5 {
    synthetic = neighbors[neighborIdx]
}
```

The problem with this is that in the case of a data set with all categorical values, this reduces to duplication of the entire record (because the same weight value is applied to each field). Instead, you might choose the value that occurs in the majority of the K nearest neighbors. Another option, the one we went with, is to use the weight to control *another* random choice between the two points (with potentially different results for each field):

```
synthetic = x
if weight < rand.Float64() {
    synthetic = neighbors[neighborIdx]
}
```

These handle a much wider range of data sets; the most significant remaining type is arbitrary text data. We have only started exploring Pilosa's capabilities in that area, so we aren't handling that here. With these modifications, and some finer control over the classes of data points produced, this just about covers our needs. Of course there are a few outstanding TODO items. In particular, computing nearest neighbors is a crucial step, and that can't be done directly on non-numeric data. As a quick workaround, we mapped categorical data to integers (with a loosely meaningful ordering when possible), and then used a standard KNN algorithm to compute neighbors. I can imagine a sort of k-d tree variant that understands categorical axes, with a custom distance metric (say, an inequality test). This would simplify the process, but it may require an unreasonable effort. Another idea is to generate synthetic data points based on a combination of more than just one neighbor, but it's not clear how beneficial this would be.

Despite being a quick prototype, this is all pretty fast. For a base dataset of about about 41,000 records, with 15 fields of various types, we can generate just over one million synthetic data points (25x oversampling) in about 23 seconds. Generating ten million points takes about 430 seconds. Finding nearest neighbors takes eight seconds, and the synthesis time *should* scale linearly with the output size. This is in python/numpy, so there is lots of room for improvement. We will likely rewrite this in Go, the next time we need a billion synthetic data points.

One last note: despite a perhaps-unreasonable focus on the quality of test data, there are no guarantees regarding the statistical validity of this variant of SMOTE. I would not suggest using it for any sort of predictive modeling work without further study.

[Try it out](https://github.com/alanbernstein/smote)!

_Banner image by Felix Mittermeier on Unsplash_
