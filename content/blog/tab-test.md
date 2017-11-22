+++
date = "2017-11-20"
publishdate = "2017-11-20"
title = "Tab Test"
author = "Alan Bernstein"
author_twitter = "gsnarky"
author_img = "5"
image = "/img/blog/hello-world.png"
disable_overlay = true
overlay_color = "blue" # blue, green, or light
+++

here is some text

below here should be some language tabs: curl, python and go


{{% tabs curl python go %}}
{{% tab lang="curl" %}}
```sh
curl printf.net/blah-blah
```
{{% /tab %}}

{{% tab lang="python" %}}
```python
print('blah blah')
```
{{% /tab %}}

{{% tab lang="go" %}}
```go
fmt.Println("blah blah")
```
{{% /tab %}}

{{% /tabs %}}


here is a second example with actual code, for curl, python, go, java, lua. note that clicking buttons here affects the tabs in the previous container as well. that means clicking the java or lua buttons hides everything in the previous container. three options:

- modify the javascript for this approach, to only hide the old-active-pane if the new-active-pane is present. moderately more complex to code.
- only use these tabs when all containers on a page have the same set of languages. this seems reasonable - if a user is following an example, they'll want to complete it in one language. problem: if one of N languages requires no code to accomplish some subtask.
- use two sets of shortcodes: this one, that switches all containers, and a second one, where buttons only switch the corresponding panes. this might be annoying for authors to keep track of.

{{% tabs curl python go java lua %}}
{{% tab lang="curl" %}}
```sh
curl localhost:10101/index/i/query -XPOST -d "SetBit(0, 0, frame=f)"
```
{{% /tab %}}

{{% tab lang="python" %}}
```python
client.query(myframe.setbit(5, 42))
```
{{% /tab %}}

{{% tab lang="go" %}}
```go
response, err := client.Query(myframe.SetBit(5, 42))
```
{{% /tab %}}

{{% tab lang="java" %}}
```java
client.query(myframe.setBit(5, 42));
```
{{% /tab %}}

{{% tab lang="lua" %}}
```lua
client:query(frame:setbit(10, 20))
```
{{% /tab %}}

{{% /tabs %}}


here is some lame text

```python
str='here is a basic code fence'
```
