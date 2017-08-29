+++
date = "2017-05-05"
publishdate = "2017-05-05"
title = "OSCON 2017: The Index As a First Class Citizen"
author = "Ali Cooley"
author_twitter = "slothware"
author_img = "1"
image = "/img/blog/binary-banner.png"
overlay_color = "green" # blue, green, or light
+++

Don’t miss Pilosa’s Lead “Slothware” Engineer, Matt Jaffee, at his [O'Reilly Open Source Convention](https://conferences.oreilly.com/oscon/oscon-tx) speaking debut! Titled [_The Index As a First-Class Citizen_](https://conferences.oreilly.com/oscon/oscon-tx/public/schedule/detail/60565), Jaffee will explore what happens when you take the index out of the database and make it a separate application—one that is distributed, scalable, and takes full advantage of modern, multicore, high-memory hardware. Jaffee’s talk will be on Wednesday, May 10th at 11:00 AM in Meeting Room 13.

<!--more-->

Jaffee will discuss the traditional role of databases, which are responsible for both storing and indexing data so that it can be kept safely and accessed quickly. Modern at-scale software architecture, however, has increasingly tended toward breaking things apart (e.g., microservices), which databases have, with few exceptions, resisted.

Our answer to this problem is Pilosa, an open-source, distributed, sparse bitmap index that exists as an acceleration layer over existing data stores, which is being successfully used in production to accelerate queries that were otherwise impractical due to high latency and excess memory use. Pilosa can be used to speed up certain queries to existing databases, or make joining data from multiple stores much faster.

Jaffee covers some background on databases and indexes and discusses the pros and cons of separating the index from the storage before diving into a general overview of Pilosa and a demonstration of how it can be used to reduce latency and enhance data exploration.

Whether or not you can make the presentation, you can catch Jaffee throughout OSCON at our booth in the Expo Hall (#532), or at any of these [Pilosa-sponsored OSCON events](/blog/pilosa-at-oscon-2017/).

We hope to see you there!
