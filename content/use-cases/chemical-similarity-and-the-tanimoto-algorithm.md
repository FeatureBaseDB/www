+++
date = "2017-05-01"
title = "Chemical Similarity and the Tanimoto Algorithm"
+++

## Overview

The notion of chemical similarity (or molecular similarity) plays an important role in predicting the properties of chemical compounds, designing chemicals with a predefined set of properties, and especially conducting drug design studies. These are often accomplished by screening large indexes containing structures of available or potentially available chemicals.

Calculation of the similarity of any two molecules is achieved by comparing their molecular fingerprints. These fingerprints are comprised of structural information about the molecule which has been encoded as a series of bits.  But the research suffers from one of the classic 3Vs of big data: volume. The sheer number of possible molecules, petabytes of data, and solutions that grow O(N^2) make the research difficult and costly. 


>"Similarity measures based on the comparison of dense bit vectors of two-dimensional chemical features are a dominant method in chemical informatics. For large-scale problems, including compound selection and machine learning, computing the intersection between two dense bit vectors is the overwhelming bottleneck." Imran S. Haque†, Vijay S. Pande†‡, and W. Patrick Walters*§
†Department of Computer Science and ‡Department of Chemistry, Stanford University [1](https://www.ncbi.nlm.nih.gov/pubmed/21854053)


Since Pilosa is a bitmap index, it is particularly suited to answering questions based on logical operations against massive data sets.  It can search through millions of molecules and find those most similar to a given molecule. 

For example, one commonly used algorithm to calculate the similarity is the Tanimoto coefficient. In the Tanimoto Algorithm A and B are sets of fingerprint bits on in the fingerprints of molecule A and molecule B. AB is the set of common bits of fingerprints of both molecule A and B. The Tanimoto coefficient ranges from 0 when the fingerprints have no bits in common, to 1 when the fingerprints are identical.

```
T(A,B) = (A ^ B)/(A + B - A^B)
```

## Data model

To model data in Pilosa, one must choose what the columns represent and what the rows represent. Let each column to represent a molecule id and each row represent a bit position within the digital fingerprint. 
 
Pilosa stores information as a series of bits, and in this case one can use RDKit in Python to convert molecules from their SMILES encoding to Morgan fingerprints, which are arrays of “on” bit positions. 

Then one is able create a data model in Pilosa as so:

|             |   Bit Position - Fingerprint 1 |  Bit Position - Fingerprint 2 | ... |
|------------------|---------|------|--------------------------|
| chembl_id 1 |  0 | 0 | |
| chembl_id 2 |  1 | 1 | |
| chembl_id 3 |  1 | 1 | |
| chembl_id 4 |  1 | 1 | |
| chembl_id 5 |  1 | 0 | |
| chembl_id 6 |  1 | 0 | |

## Query

Pilosa has a host of functions including TopN and Tanimoto Threshold. Using Pilosa's query language, here is an example using both to get a list of similar chembl_id' s.

    
```python
query_string = 'TopN(Bitmap(id=6223, frame="mole.n"), frame="mole.n", n=2000000, tanimotoThreshold=70)'
topn = requests.post("http://127.0.0.1:10101/index/mol/query" , data=query_string)
```

## More

For a deeper dive on how to use implement Chemical Similarity in Pilosa and how to use the Tanimoto Algorithm check out the links below. 

<a href="https://www.ebi.ac.uk/chembl/downloads" class="btn-pilosa btn btn-primary m-2">Data</a>
<a href="https://www.pilosa.com/docs/tutorials/#chemical-similarity-search" class="btn-pilosa btn btn-primary m-2">Tutorial</a>
