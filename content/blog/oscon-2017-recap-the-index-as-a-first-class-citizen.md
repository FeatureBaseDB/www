+++
date = "2017-06-24"
publishdate = "2017-06-24"
title = "OSCON 2017 Recap: The Index As a First Class Citizen"
author = "Ali Cooley"
author_img = "1"
featured = "true"
image = "/img/blog/oscon-2017-recap-the-index-as-a-first-class-citizen/banner.png"
overlay_color = "blue" # blue, green, or light
+++
 
OSCON 2017 was our first conference as a company. Held in our backyard here in Austin, TX, and coming just days after our official launch, it was an excellent introduction into the open source community. 

<!--more-->

Our entire team was on the ground attending sessions, meeting other open source enthusiasts, and trying to locate as many free fidget spinners as possible. With all of us dashing around the Austin Convention Center, it was difficult to get anyone together for a group photo, though we did manager to attend one session as a company. Pilosa showed up in force to support our very own Matt Jaffee. One of our Lead Slothware Engineers, Jaffee spoke about our mission to separate the index from storage, and its multiple advantages for query speed. 
 
A database is traditionally responsible for both storing and indexing data so that it can be kept safely and accessed quickly. Modern at-scale software architecture has increasingly tended toward breaking things apart (e.g., microservices), which databases have, with few exceptions, resisted. That’s why we created Pilosa, an open source distributed, sparse bitmap index that exists as an acceleration layer over existing data stores, which is being successfully used in production to accelerate queries that were otherwise impractical due to high latency and excess memory use. Pilosa can be used to speed up certain queries to existing databases, or make joining data from multiple stores much faster.
 
Jaffee covers some background on databases and indexes and discusses the pros and cons of separating the index from the storage before diving into a general overview of Pilosa and a demonstration of how it can be used to reduce latency and enhance data exploration. Check out the full video, below:
 
<div style="position:relative;height:0;padding-bottom:56.21%"><iframe src="https://www.youtube.com/embed/6gsD2Uohb5k?ecver=2" style="position:absolute;width:100%;height:100%;left:0" width="641" height="360" frameborder="0" allowfullscreen></iframe></div>
