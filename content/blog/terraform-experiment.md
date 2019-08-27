+++
date = "2019-08-27"
publishdate = "2019-08-27"
title = "Building Throwaway Machines with Terraform"
author = "Todd Gruben"
author_twitter = "tgruben"
author_img = "1"
image = "/img/blog/experiment/banner.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

Looking for an easy way to quickly try out some new whiz-bang software safely and securely? Look no further!

<!--more-->

At my day job at [Molecula](https://www.molecula.com/), I often find myself needing to perform a simple experiment and I
run off and install a bunch of tools, run a bunch of tests, make brilliant
observations and then go onto the next Big Thing.  The problem with this approach is
if I run my experiments on my local laptop, it becomes cluttered and the cruft
builds up into an unmanageable rats nest.  When I run my experiments on
machines in the cloud, many juicy artifacts are often lost when my cloud machine
is destroyed.  I usually capture the major focus of the experiement in notes,
but later I realize that I missed something that was contained in the output of
a command or even what commands I actually executed.  So following the [grunt work principle](http://www.jasontconnell.com/comment/grunt-work-principle),
this task must be automated.

### Setup
First, install the awesome Terraform, a cloud provisioning tool from
[HashiCorp](https://www.hashicorp.com/). This basically requires putting an executable in your path, but the
install process is described in detail at [HashiCorp](https://learn.hashicorp.com/terraform/getting-started/install.html).

Once this is installed, you have to craft a few files that describe which cloud
provider to connect to and how to set it up.  The links below are the ones I use
for GCP (Google Cloud Platform), and those files assume you have exported your google
credentials to a local file `credentials.json` file from the GCP dashboard, you use an RSA key
(`~/.ssh/id_rsa.pub`) in your home directory and you have generated a gist cli access token (`~/.gist`), the process to generate is described [here](https://github.com/defunkt/gist). After those files are in place
simply `init` and `apply` and you are off to the races. You will have to replace the project value in the `main.tf` with `project_id` value located your `credentials.json`

{{< gist tgruben 79b22e07fd6d9782c5c7112aed6520aa >}}

```
terraform init
terraform apply
```
Once it's all up and running you can access that machine by

```
ssh ubuntu@`terraform output ip`
```

And finally cleanup when you're done with

```
terraform destroy
```

All ssh sessions are recorded to log files which preside in the ubuntu home directory `/home/ubuntu` of the generated machine.  When the machine is destroyed via terraform those logs are uploaded to a [gist](https://gist.github.com) which has the nice feature of making the content of the gist indexed and searchable via [search](https://gist.github.com/search).  Don't forget to limit to just your gists by adding the user filter that looks something like `user:tgruben`.  It should be noted that gists are publicly viewable.  You can add  the private flag `-p` from the destroy hook in `main.tf` and the content is not `discoverable` but it is still viewable by the public if you can find the link.

I hope you find this useful.
