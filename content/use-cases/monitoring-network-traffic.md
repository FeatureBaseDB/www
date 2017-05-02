+++
date = "2017-05-01"
title = "Monitoring Network Traffic"
+++

Pilosa enables humans and machines correlate, filter, query, and otherwise make sense of massive volumes of network packet data.
  
There are myriad reasons to study the data that traverses computer networks. Maybe a researcher wants to understand how traffic patterns change over time, or an operator wants to know what types of traffic happen most frequently so that she can optimize the network for the particular load it sees. Perhaps most importantly, those who defend our computer systems from threats both internal and external require a deep understanding of the traffic which traverses their networks. One cannot detect abnormal traffic without a good understanding of normal traffic.
  
Even moderately sized networks move a staggering amount of information on a day to day basis - so much that getting even basic statistics about it is a daunting task. Any solution to this problem must:
* be horizontally scalable
* represent the data as compactly as possible
* support high speed streaming ingest
* be queryable in real time (in order to help respond to anomalies quickly)
  
Pilosa is a distributed, sparse, bitmap index - not only can it represent each feature of a packet as a single bit, it intelligently compresses each bitmap, or in some cases doesn’t store them at all (e.g. if no bits are set), resulting in a massive reduction in the size of the index. Additionally,Pilosa will spread itself over a large number of hosts, increasing both the amount of space and processing power available to run queries.
  
Through a combination of distributed counting, segmentation, filtering, and sorting, Pilosa can support complex queries with miniscule latency - returning vital traffic statistics in near real-time.

## Data Model

The abstract representation of Pilosa’s data model is a 2 dimensional binary matrix. Pilosa divides the rows of the matrix into categories called “frames”; each frame maintains its rows in sorted order by the number of columns which are set, so it is important to pick frames wisely.
   
To model network data in Pilosa, one must choose what the columns represent, what the rows represent, and how the rows are divided into frames. Let each column to represent a single packet, and each row represent some feature a packet may have. For example if a packet has a certain destination IP address like “10.3.2.1", then one would have a row for “10.3.2.1”, a column for this particular packet, and the bit at their intersection would be set.
   
One could decide that all destination IP addresses would be in a frame together, which would enable queries like “What are the top destinations of traffic in my network?“. One can extrapolate this model to other features of packets and see what we come up with:

| Row Name                                    | Packet1            | Packet2            | ... | Frame Description        |
|---------------------------------------------|--------------------|--------------------|-----|--------------------------|
| 10.3.2.1<br>8.8.8.8<br>...                  | 0<br>1<br>...      | 1<br>0<br>...      |     | Source IP Address        |
| 5.4.3.2<br>192.168.1.3<br>...               | 1<br>0<br>...      | 0<br>1<br>...      |     | Destination IP Address   |
| 34567<br>45388<br>...                       | 0<br>1<br>...      | 1<br>0<br>...      |     | Source Port              |
| 80<br>443<br>...                            | 0<br>1<br>...      | 1<br>0<br>...      |     | Destination Port         |
| IPv4<br>IPv6<br>ICMP<br>...                 | 0<br>1<br>0<br>... | 1<br>0<br>0<br>... |     | Network Layer Protocol   |
| TCP<br>UDP<br>SCTP                          | 0<br>0<br>1<br>... | 1<br>0<br>0<br>... |     | Transport Layer Protocol |
| HTTP<br>DHCP<br>DNS<br>...                  | 1<br>0<br>0<br>... | 1<br>0<br>0<br>... |     | App Layer Protocol       |
| google.com<br>espn.com<br>...               | 1<br>0<br>...      | 0<br>1<br>...      |     | Hostname                 |
| POST<br>PUT<br>...                          | 1<br>0<br>...      | 1<br>0<br>...      |     | HTTP method              |
| application/html<br>application/json<br>... | 0<br>1<br>...      | 0<br>1<br>...      |     | Content-Type             |
| Firefox/Windows<br>Chrome/Linux<br>...      | 1<br>0<br>...      | 0<br>1<br>...      |     | User Agent               |
| 1500<br>64<br>...                           | 0<br>1<br>...      | 1<br>0<br>...      |     | Packet Size (bytes)      |
| ACK<br>SYN<br>...                           | 1<br>0<br>...      | 0<br>1<br>...      |     | TCP Flags                |

## Querying

Now that one has a data model, what sorts of queries can we easily (and quickly) answer with Pilosa?

Get the top websites accessed by a given person. 

`TopN(Intersect(Row(srcIP=X.X.X.X), Row(user-agent=“Mozilla/5.0 (Windows; rv:40.0) Gecko Firefox/40.1”)), frame=hostname)`

Analyze packet sizes for a given time range (could be useful in identifying DDoS attacks).
`TopN(frame="packet_size::timestampHH")`

Find the top ports/protocols/packet sizes between any two hosts: 
`TopN(Intersect(Row(srcIP=X.X.X.X), Row(dstIP=X.X.X.X)), frame="ports/protocols/packet sizes")`

How much IPv4 vs IPv6 traffic? (in a given time interval?) 
`Count(Range(id=IPv4, start=ts1, end=ts2)) vs Count(Range(id=IPv6, start=ts1, end=ts2))`

Who is sending the most DNS traffic? 
`TopN(Row(id=DNS, frame="app_layer_proto"), frame="srcIP")`

Top DNS servers? 
`TopN(Row(id=DNS, frame="app_layer_proto"), frame="dstIP")`
     
These are all just single queries. Interesting things can happen by combining multiple queries? Let’s try to identify web communities, not based on hyperlinks between pages, but by which pages users access together. First, choose a target site and find its top users with something like:
  
`TopN(Bitmap(id=targetsite.com, frame="hostname"), frame="srcIP")`. 
   
For each of those IPs, look at the top sites they access:
  
 `TopN(Bitmap(srcIP="x.x.x.x"), frame="hostname::timestampHH")`
  
With that information, one can build a bigraph of sites and users and analyze cliques to determine groups of sites that are commonly accessed together.
   
## Try it out!  
We provide a sample implementation of this functionality which you can try out on your personal machine. It can capture live traffic, or read from a pcap file and load the data into pilosa.
 
First, [install Pilosa](/docs/installation/) and the [Pilosa Dev Kit](/docs/pdk/)
   
Now you can run (on most macs): `pdk net -i en0`. This will do several things - `pdk` will use libpcap to inspect all network traffic on interface `en0`, it will extract all the features of packets discussed in the data model, and start importing them into Pilosa. PDK will also start up a proxy server and store all the information to map Pilosa’s bitmap ids, to what they actually represent. This is very important, because pilosa only knows about integer ids internally, but we’ll want to make queries like `TopN(Row(id=192.168.1.2, frame=srcip), frame=hostname)` PDK’s proxy server will generate something like `TopN(Row(id=3478245, frame=srcip), frame=hostname)` and send that on to Pilosa. Pilosa will generate a response with a list of bitmap ids which represent the top hostnames with which 192.168.1.2 has communicated. PDK will translate those integer ids into hostname strings and return a list of hostnames back to you.
   
All that being said, you should query PDK’s proxy server rather than Pilosa directly, and you can use ip addresses and hostnames and so on rather than having to know the integer id for each row.

## Production Thoughts
If you attempt to use Pilosa in this capacity, there are a few considerations which should be addressed beforehand.

Although pilosa indices with billions of columns have been tested with excellent performance, using one column per packet will likely load Pilosa orders of magnitude beyond this - scaling into the trillions of columns is uncharted territory, and we would be very excited to hear about any experiences at this scale. Storing metadata about flows is probably a more viable choice. Another option would be to tweak the data model to use IP addresses for the columns - this would put a hard upper limit on the number of columns (though IPv6 might have to be handled separately), and provide interesting opportunities for per-host analysis.

Handling the mappings from row id to ip address, hostname, user agent, and other high cardinality fields is a separate class of issue which has not been deeply covered here. The PDK simply holds the mappings in memory for its mapping proxy server, but in a production environment, one would want those mappings to be handled in a durable and scalable way - probably by using a separate key/value store.

In a large network, there will likely be many points of capture all writing to Pilosa. Some form of coordination will be necessary to ensure that column ids are not used by more than one packet and row ids map to one and only one value (such as an IP address or hostname). Although the feasibility of actually storing all the raw pcap data is questionable in large networks, it looks slightly less daunting if each point of capture stores the data locally rather than moving it across the network again. If you know which capture point is responsible for a given range of packet ids, you may still be able to quickly retrieve full pcap data after having narrowed down which packets you are looking for in Pilosa. This capability would undoubtedly be extremely valuable.


<a href="https://stratosphereips.org/category/dataset.html" class="btn-pilosa btn btn-primary m-2">Data</a>
<a href="https://www.pilosa.com/docs/query-language/" class="btn-pilosa btn btn-primary m-2">PQL</a>
