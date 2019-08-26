+++
date = "2019-08-27"
publishdate = "2019-08-27"
title = "Building throw away Machines with terraform"
author = "Todd Gruben"
author_twitter = "tgruben"
author_img = "2"
image = "/img/blog/experiment/banner.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

Looking for an easy way to quickly try out some new whiz-bang software safely and securely? Look no further!

<!--more-->

At my day job at [Molecula](https://www.molecula.com/), I often find myself needing to perform a simple experiment and I
run off and install a bunch of tools, run a bunch of tests, make brilliant
observations and then go onto the next Big Thing.  The problem with this approach is
if I run my experiments on my local laptop, it becomes cluttered and the kruft
builds up into an unmanageable rats nest.  When I run my experiments on
machines in the cloud, many juicy artifacts are often lost when my cloud machine
is destroyed.  I usually capture the major focus of the experiement in notes,
but later I realize that I missed something that was contained in the output of
a command or even what commands I actually executed.  So following the grunt
work principle, this task must be automated.

### Setup
First, install the awesome terraform, a cloud provisioning tool from
hashicorp. Its basically just putting an executeable in your path, but the
install process is decribed in detail at [Hashicorp](https://learn.hashicorp.com/terraform/getting-started/install.html)

Once this is installed you have to craft a few files that describe what cloud
provider to connect to and how to set it up.  The links below are the ones I use
for GCP(Google Cloud Platform), and those files assume you have exported your google
credentials to a local file credentials.json file from the GCP dashboard and you use an RSA key
(~/.ssh/id_rsa.pub) in your home directory. After those files are in place
simply init and apply and you are off to the races.

{{< gist tgruben f74305a2e9b36e48ddef689d90271e9f "main.tf" >}}

{{< gist tgruben f1a3060569192f04d6407757e6e70ae7"output.tf" >}}

```
terraform init
terraform apply
```
Once its all up and running you can access that machine by

```
ssh ubuntu@`terraform output ip`
```

And finally cleanup when your done with

```
terraform destroy
```

I hope you find this useful.
