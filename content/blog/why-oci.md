+++
date = "2019-01-13"
publishdate = "2018-11-13"
title = "Managed Service on OCI"
author = "Matt Jaffee"
author_twitter = "mattjaffee"
author_img = "2"
featured = "true"
image = "/img/blog/seed-round/banner.jpg"
overlay_color = "green" # blue, green, or light
+++

When it comes to choosing a cloud provider, Oracle probably isn't the first company that comes to mind. I think most people would agree that the order is something like:

1. AWS
2. Azure
3. Google Cloud Platform
4. Others...

We've the good fortune of recently being chosen to participate in the Oracle Startup Accelerator program, which among other things meant we got a whole boatload of credits for Oracle's cloud offering.

As we started to take it for a spin, we were pleasantly surprised by a number of things:

1. It emulates AWS in a lot of ways, so it feels fairly familiar.
2. It was built from the ground up to work with [Terraform](https://www.terraform.io/) which is muy bueno.
3. The costs were quite competitive, especially considering the amount of memory and SSD available.

Check out this table:

| Cloud | Type            | n |   $/hr | Total Mem | Total Threads | Storage/node |
|-------|-----------------|---|--------|-----------|---------------|--------------|
| OCI   | VM.Standard2.16 | 3 | 3.0624 |       720 |            96 | 0            |
| OCI   | VM.DenseIO2.16  | 3 |   6.12 |       720 |            96 | 12.8 TB NVME |
| OCI   | BM.Standard2.52 | 1 | 3.3176 |       768 |           104 | 12.8 TB NVME |
| OCI   | BM.HPC2.36      | 2 |    5.4 |       768 |           144 | 6.7 TB NVME  |
| Azure | F32s v2         | 3 |  4.059 |       192 |            96 | 256 GB SSD   |
| Azure | F16             | 6 |  4.776 |       192 |            96 | 256 GB SSD   |
| Azure | Standard_D32_v3 | 3 |  5.616 |       384 |            96 |              |
| AWS   | c4.8xlarge      | 3 |  4.773 |       180 |           108 | 0            |
| AWS   | c5.9xlarge      | 3 |   4.59 |       216 |           108 | 0            |
| AWS   | r4.8xlarge      | 3 |  6.384 |       732 |            96 | 0            |
| AWS   | h1.8xlarge      | 3 |  5.616 |       384 |            96 | 8TB HDD      |
| AWS   | c5d.9xlarge     | 3 |  5.184 |       216 |           108 | 900 GB       |

In particular, a 2 node HPC2.36 cluster on OCI is comparable in price to a 3 node c5d.9xlarge on AWS, but has 5x the SSD space, significantly more processors, and triple the memory. 

These basic numbers don't tell the whole story of course - there are hundreds,
or even thousands of different hardware and software choices that a cloud
provider has to make when building their offering. Networking fabric, disk make
and model, processor type, motherboard, memory speed, network card, and
hypervisor just to name a few - not to mention the myriad configuration options,
any of which might have a drastic impact on performance. Some of these things
are published, or can be determined from inside of an instance, but many or even
most of them are intentionally abstracted away from the user. The only really
reliable way to see how different providers stack up is to run your workload on
them and measure its performance!


