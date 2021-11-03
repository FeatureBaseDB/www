This directory contains a markdown version of our whitepaper.

# Setup
You need to:

```
brew install pandoc
brew install pandoc-citeproc
```

Install [MacTeX](http://www.tug.org/mactex/).


# Make PDF
`make`

# Notes

The generated pdf looks ok, but nothing like what our original whitepaper did. I
borrowed the template from
[here](https://github.com/Wandmalfarbe/pandoc-latex-template), there is also a
default template which pandoc will use which looks much worse. You can output
this default template for fiddlin by executing `pandoc -D latex`.

I got a more "journaly" two column format working using
[this](https://github.com/kdheepak/pandoc-ieee-template) and editing paper.md,
but the font is awful, and changing it seemed like it would be a world of hurt.
If anyone is interested in pursuing that path I can share the changes I made to
that repo with you.

There are other avenues we could take - pandoc can generate a variety of formats
besides PDF, and can generate PDF in a variety of ways other than latex. We can
also render it directly to HTML and put it on our website with Hugo bypassing
this whole song and dance entirely.
