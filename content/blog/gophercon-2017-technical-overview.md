+++
date = "2017-07-26"
publishdate = "2017-07-26"
title = "Gophercon 2017: Technical Overview"
author = "Matt Jaffee, Linh Vo, and Travis Turner"
author_img = "3"
featured = "true"
image = "/img/blog/gophercon-2017-technical-overview/banner.png"
overlay_color = "blue" # blue, green, or light
+++

In addition to sponsoring Gophercon 2017, our team sent several of us engineers to Gophercon. Predictably, we all had a blast. As you may have guessed, Pilosa is written in Go, so this conference was particularly important to us. We felt that we should try to get the most from our time in Denver, so between us, we attended every. Single. Talk. Like all good Gophers, we used the time between sessions to compare notes and discuss takeaways from each. 

<!--more-->

Three of us put together topline selection of our findings, although we will be writing more in the next few weeks and doing some deep dives about our favorite sessions.

### Jaffee: Forward Compatible Go Code
[Joe Tsai's talk](https://www.youtube.com/watch?v=OuT8YYAOOVI&index=3&list=PL2ntRZ1ySWBdD9bru6IR-_WXUgJqvrtx9) on what is – and more importantly – what isn't in the Go 1 compatibility promise had both immediate and long term ramifications for Pilosa. One thing people love to do for new Go releases is benchmark their performance against the past release; as we near Go 1.9, I'm looking forward to seeing what effect the new compiler and runtime has on Pilosa's performance. As I was watching Joe's talk, however, it occurred to me that we might not be able to trust all of our benchmarks to provide consistent results during the transition.

Many of Pilosa's benchmarks use `math/rand` to generate random data before querying it. We always provide a fixed seed to the random number generator so that we can have more reproducible results across each run of a given benchmark. How sparsely or densely data is stored in Pilosa, along with how it's distributed (bunched up or spread evenly?) can have a significant impact on performance. Joe's talk called out "packages with unstable output", and one of them was `math/rand`. When we upgrade to 1.9 and run benchmarks that use `math/rand`, we won't necessarily be generating the same data sets that we were previously, and therefore it's difficult to know if performance changes are due to the new Go version, or just due to different data. Armed with this knowledge, however, we can do multiple runs with different random seeds and compare the average performance across the two Go versions. As long as we account for stark outliers, we should be able to get a pretty good idea of how the new version of Go is affecting performance.

![Regression Testing Failures](/img/blog/gophercon-2017-technical-overview/regression-testing-failures.png)

Joe's talk had many other pieces of wisdom, but one that I thought stood out was a chart showing the number of the test failures in Go over a release cycle, above. Go's release cycle consists of 3 months of feature additions plus 3 months of code freeze and testing. Spending half of your dev time with a frozen code base might seem like overkill, but to me, this chart clearly showed the benefits of code freezes in complex projects. The code freeze started right at the center of this chart where the blue area is at its apex. Extrapolating from the data, one can imagine what might happen if the code freeze were not enforced: the project would
accrete a critical mass of bugs and slowly suffocate under the burden. Development and maintenance of a project with a huge number of bugs and stability issues is like going for a run in a pool of molasses.

Until now, Pilosa's release cycle has been fairly fast and loose – bugs and stability problems are generally prioritized higher than other issues, but it isn't a hard rule. In light of this chart, we'll have to carefully consider how we want to manage our release cycle as we march steadily closer to Pilosa v1.0.

### Linh: Advanced Testing with Go
[Mitchell Hashimoto](https://github.com/mitchellh), the founder of HashiCorp, delivered an incredibly dense [keynote on Go testing patterns](https://www.youtube.com/watch?v=8hQG7QlcLBk&list=PL2ntRZ1ySWBdD9bru6IR-_WXUgJqvrtx9&index=12) employed at his company. To illustrate what I mean by dense: His keynote covered 30 entirely different methods of writing testable codes. While he mentioned being unsure as to whether his keynote would be beneficial for everyone, I learned quite a few valuable lessons.

A common thread throughout his talk was that you can’t just take any kind of code and test it. Mitchell declared that there are two different but equally important components of a good test: test methodology, or how you write tests, and writing testable code. Hint: It’s a lot more complicated than just using `assert(func() == expected)`. 

Writing testable code implies writing code in a way that can be easily tested, which is harder than it sounds. Like many other developers, I often write code that I think can’t be tested. But the truth is I might have written the code in a way made it too hard to test. While rewriting code so it can testable seems painful, Mitchell’s talk proved that it can be worthwhile in the long run.

Throughout his keynote, Mitchell introduced his testing methods in greater detail. He started with simple testing methods and proceeded to more advanced techniques, such as table driven tests to interfaces and mocks. One of the good tip (that I used to ignore) was that even with a single test case, we can still set up a table driven structure, as there may a scenario we want to test other parameters on in the future.

He also covered testing features in newer Go versions, such as subtest in Go 1.8, which we have been adopting for our own tests as we upgrade to Go 1.8, and test helper in Go 1.9. I encourage you to find out more of these important features by watching Mitchell’s talk online, [posted here](https://www.youtube.com/watch?v=8hQG7QlcLBk&list=PL2ntRZ1ySWBdD9bru6IR-_WXUgJqvrtx9&index=12). While we may not apply all of his methods to improve Pilosa test coverages, they’re useful guidance in our efforts to achieve greater test coverage, and more readable, maintainable, simpler code.


### Travis: Go Build Modes
David Crawshaw's [talk on Go Build Modes](https://www.youtube.com/watch?v=x-LhC-J2Vbk&index=7&list=PL2ntRZ1ySWBdD9bru6IR-_WXUgJqvrtx9) was very in-depth and provided really good insight to anyone interested in the various build modes available to Go developers. He covered all eight build modes currently supported by the Go compile tool chain:
- exe (static)
- exe (with libc)
- exe (with libc and non-Go code)
- pie
- c-archive
- c-shared
- shared
- plugin

Given that we at Pilosa have committed a fair amount of resources toward building and testing Go plugins (available in Go as of version 1.8), I was curious to get David's perspective on them. Not surprisingly, his assessment of plugins pretty much corroborated the conclusion we had already come to: "If you ask me 'should I use plugins?' the answer is no". In general, it
seems like plugins are only useful when you have an extremely large development team working on a single code base.

In addition to the `plugin` build mode, it was interesting to hear David's explanation of the `pie` build mode. This build mode, which stands for "Position Independent Executables" was new to me. From the outside, it behaves exactly like a standard executable, but internally it allows the executable to be placed anywhere in memory. To accomplish this, the compiler uses relative addressing in jump instructions. Where the linker would typically know exactly what position in memory a jump instruction should point to, relative addressing allows the jump instruction to point to a position in memory relative to the current instruction. All of this helps support an OS security feature called ASLR (address space layout randomization), which places an executable in a different space in memory every each time the executable starts. This repositioning of the executable helps to mitigate security attacks, and in fact `pie` is required by some operating systems like Android OS.

*Cover image artwork was created using the Gopherize.me app created by Ashley McNamara and Mat Ryer, with artwork inspired by Renee French.*
