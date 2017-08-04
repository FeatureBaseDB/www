+++
date = "2017-08-04"
publishdate = "2017-08-04"
title = "Self Deploying Applications Without Kubernetes"
author = "Matt Jaffee"
author_img = "2"
image = "/img/blog/self-deploying/banner.jpg"
overlay_color = "" # blue, green, or light
disable_overlay = true
+++

What if your apps handled their own ops? That's kind of like devops' final form,
right? Its ultimate evolution? The Charizard of devops, if you will. 

Inspiration to write about this comes from Kelsey Hightower who had a good talk
at Gophercon about
[Self Deploying Kubernetes Applications](https://www.youtube.com/watch?v=XPC-hFL-4lU).
Here's the TLDR;

`myapp --kubernetes --replicas=5`

myapp compiles itself statically for Linux, containerizes itself, and deploys to
a Kubernetes cluster with 5 replicas. No config files needed.

I thought this was extremely cool, and immediately went to check out Kubernetes
to see if I could add something like it to Pilosa. Kubernetes' docs have a
page dedicated to "picking the right solution," which has 40+ different ways to
get going with Kubernetes, none of which (as far as I could tell) were "run this
binary". Bleeeeccchhh - I don't want to dig through pages of documentation just
for a quick experiment. I've heard great things about Kubernetes, and I'm sure
it has good reason for such complexity, but I was really smitten with the
"self-deploying applications" idea, not the "on Kubernetes" part.

In fact, I'd already done some work in this direction for Pilosa's benchmarking
suite. The original idea was to build a tool which would, with a single command: 

- provision cloud infrastructure on various providers
- install and start a Pilosa cluster on remote hosts
- allow for highly configurable benchmarks to be defined
- install and run benchmarks on remote "agent" hosts
- gather the results of the benchmarks
- gather host metrics (cpu, memory, etc.)
- store all the data from each benchmark run in a consistent format
- make and serve delicious iced beverages

Wow, once that I put it in a list like that it looks pretty ridiculous - now I
understand why it has taken us something like 8 months. In any case, we've
actually achieved a few of those goals with a new tool
called [Pi](https://github.com/pilosa/tools) which we are open sourcing *today*.

Right, but self deploying applications, that's why you're here. Let's set aside
the cloud provisioning part of the equation for now, and say you have a set of
fresh, clean, Linux hosts to which you have ssh access, and you want to
benchmark Pilosa. You've got Pilosa's codebase locally (in your `GOPATH`) as
well as the mythical Pi tool. What's the least amount of work you could
expect to do to run a benchmark against a Pilosa cluster and gather the results?

How about running a single command, on your laptop, in a crowded, local coffee
shop, in the heart of Austin TX?

`pi spawn --pilosa-hosts=<...> --agent-hosts=<...> --spawn-file=~/my.benchmark`

You hit enter, and a few minutes later you've got benchmarking data in front of
you. A multi-node Pilosa cluster was created along with a number of agent hosts
to send queries to it. The agents spewed huge amounts of realistically
distributed random data into the cluster, and then followed it up with a battery
of complex queries.

Keep in mind that before you ran Pi, that pool of remote hosts had no
knowledge of Go, Pilosa, Pi, or anything else. They were just the stock
Linux images from AWS or GCP or whatever.

How can we do that? Let's break this down: first of all, we need to be able to
connect with remote hosts via ssh inside a Go program. Turns out Go has a pretty
great [ssh package](https://godoc.org/golang.org/x/crypto/ssh) which handles most
of this for us. Once we're connected to remote hosts, we can execute commands at
a shell just like we would from a terminal! We get standard `Reader` and
`Writer` interfaces for getting data into and out of those commands, so
everything is pretty hunky-dory. But what do we run? These hosts don't have
Pilosa or Pi installed, both of which we'll need if we want to start a cluster
and benchmark it.

Well, let's just run `cat` - these hosts definitely have `cat` installed, right?
I'm pretty sure it's the law (or at least specified by POSIX) that Linux hosts
must have `cat`. Specifically, we'll run `cat > pilosa` - remember that
`Writer`? It's actually an `io.WriteCloser`, and it goes straight to `cat`'s
`stdin`. So we just write the whole Pilosa binary right into there, close it,
and the data is magically transported to a file on the remote host!

"Wait." you say... "What binary? Your laptop in that hip coffee shop in ATX is a
Macbook Pro (obviously), you don't have a Linux binary for Pilosa." 

As you may have guessed, Go saves the day again by making it *stupidly* easy to
cross compile for other platforms. Now, I know what you're thinking: "This is
about to get SWEET; he's gonna import the packages for Go's compiler, build the
new Pilosa binary directly in memory, and stream it straight into `cat` running
on the remote host. I CAN'T WAIT!"

Yeah, no, sorry - this is the guy that couldn't be bothered to run a VM to try
out Kubernetes. I looked at the source for the toolchain for a hot minute and
decided to use `os/exec` to run `go build` in a subprocess.

`com := exec.Command("go", "build", "-o", "someTempFile", "https://github.com/pilosa/pilosa")`

Oh, and we need to set the environment to make sure we build for Linux:

`com.Env = append(os.Environ(), "GOOS=linux")`

Not bad - open the temp file, `cat` it to the remote host, a little `chmod`
action to make it executable, and we're in business. Let's take a moment to
reflect upon how much Go helped us there - not just the ease of cross
compilation, but the fact that we can compile a standalone binary which is
fairly lightweight (ok like 12 megs, but that's not *too* bad), and that's all
we need in order to run our application on another host. No JVM, no interpreter
(and no worrying about version compatibility of those things with our thing) -
it's really just very refreshing - like a delicious iced beverage.

Alright, so the Pilosa binary is in place; we can build a config file, and copy
it over the same way, or just start Pilosa with command line arguments. Once it's
running, we can stream any logs back to us, or drop them in a file on the remote
host. 

Let us turn our attention to the task at hand - B E N C H M A R K I N G.
Strictly speaking, we haven't created a *self*-deploying application yet, we've
created a Pilosa deploying application - remember it's Pi which is doing all
this stuff. But we need to run Pi on remote hosts as well because Pi has all the
benchmarking tools, and there's no reason this cross-compiling `cat`ing business
won't work just as well on the source code of the very program which is running
it.

We cross-compile Pi, copy it to each of the "agent" hosts, figure out which
benchmarks we're actually supposed to run, and run them! Pi's benchmarks report
their results in JSON format on stdout which we happily collect and aggregate
back in the coffee shop. This is CRAZY, but again, we owe a debt to Go for
providing us with a concurrency model which makes this very straightforward.
We're running multiple, different programs on multiple remote hosts, which are
throwing huge amounts of data at each other and doing massive computation. All
this from one program on one laptop with a crappy WiFi connection. Not to
mention that we're streaming and combining the output from all those remote
programs into a single cohesive result structure which fully describes the
benchmark. This would truly be a nightmare in most languages.

So, there you have it. A self-deploying application *without* Kubernetes. All
you need is a pile of hosts to which you have ssh access and you too can make
complex fleets of self-deploying programs.

Check out the source code for [Pi](github.com/pilosa/tools) (especially the
`build` and `ssh` packages), and read the docs if you want to really know how to
use it - I glossed over a bunch of details and made some stuff up to make it
seem approachable 😉. Patches welcome!
