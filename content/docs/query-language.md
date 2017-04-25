+++
title = "Query Language"
+++

## Query Language

This section will provide a detailed reference and examples for the Pilosa Query Language (PQL). All PQL queries operate on a single [index]({{< ref "glossary.md#index" >}}) and are passed to Pilosa through the `/index/*index_name*/query` endpoint. You may pass multiple PQL queries in a single request by simply concatenating the queries together - a space is not needed. The results format is always:

```
{"results":[...]}
```

There will be one item in the `results` array for each PQL query in the request. The type of each item in the array will depend on the type of query - each query in the reference below lists it's result type.

Row and Column labels are set and frame and index creation time respectively. When the specification of a query says *row_label* or *col_label*, one should use the labels that were set while creating the index and frame. The default row label is `id`, and the default column label is `columnID`.

#### Conventions

* Angle Brackets `<>` denote required arguments
* Square Brackets `[]` denote optional arguments
* *Italics* denote a type that will need to be filled in with a concrete value (e.g. *string*)
* 

#### Examples

Before running any of the example queries below, follow the instructions in the [Getting Started](getting_started) section to set up an index, frames, and populate them with some data.

The examples just show the PQL quer(ies) needed - to run the query `SetBit(frame="stargazer", repo_id=10, user_id=1)` against a server using curl, you would:
```
curl -X POST "http://127.0.0.1:10101/index/repository/query" -d 'SetBit(frame="stargazer", repo_id=10, user_id=1)'
```

#### Write Operations

##### SetBit

**Spec:**

> SetBit(\<frame=*string*\>, \<*row_label*=*uint*\>, \<*col_label*=*uint*\>, [view=*string*], [timestamp=*timestamp*])


**Result Type:** boolean

**Description:**

`SetBit`, as the name implies, assigns a value of 1 to a bit in the binary matrix, thus associating the given row in the given frame with the given column.

**Examples:**

```
SetBit(frame="stargazer", repo_id=10, user_id=1)
```

This query illustrates setting a bit in the stargazer frame of the repository index. User with id=1 has starred repository with id=10.

Setbit also supports providing a timestamp. To write the date that a user starred a repository.
```
SetBit(frame="stargazer", repo_id=10, user_id=1, timestamp="2016-01-01T00:00")
```

Setting multiple bits in a single request:
```
SetBit(frame="stargazer", repo_id=10, user_id=1) SetBit(frame="stargazer", repo_id=10, user_id=2) SetBit(frame="stargazer", repo_id=20, user_id=1) SetBit(frame="stargazer", repo_id=30, user_id=2)
```

A return value of `true` indicates that the bit was changed to 1.

A return value of `false` indicates that the bit was already set to 1 and nothing changed.

##### SetBitmapAttrs

SetBitmapAttrs() supports writing attributes of the Row. 
```
SetBitmapAttrs(frame="stargazer", user_id=10, username="mrpi", active=true)
```

Set username value and active status for user = 10. These are arbitrary key/value pairs which have no meaning to Pilosa.

SetBitmapAttrs queries always return  {"results":[null]} upon success.

##### SetColumnAttrs

SetColumnAttrs() supports writing attributes of the Column. 
```
SetColumnAttrs(frame="stargazer", repo_id=10, stars=123, url="http://projects.pilosa.com/10", active=true)
```

Set url value and active status for project 10. These are arbitrary key/value pairs which have no meaning to Pilosa.

SetColumnAttrs queries always return {"results":[null]} upon success.

##### ClearBit

```
ClearBit(frame="stargazer", repo_id=10, user_id=1)
```

Remove relationship between user_id=1 and repo_id=10  from the "stargazer" frame in the "repository" index.

A return value of `{"results":[true]}` indicates that the bit was toggled from 1 to 0.

A return value of `{"results":[false]}` indicates that the bit was already set to 0 and nothing changed.


#### Read Operations

##### Bitmap

Query all repositories that user 1 has starred.
```
Bitmap(frame="stargazer", user_id=1)
```

Returns `{"results":[{"attrs":{"username":"mrpi","active":true},"bits":[10, 20]}]}`

* attrs are the attributes for user 1 
* bits are the repositories which user 1 has starred.

##### Union

Query all repositories that are contributed by multiple users
```
Union(Bitmap(frame="stargazer", user_id=1), Bitmap(frame="stargazer", user_id=2)))
```

Returns `{"results":[{"attrs":{},"bits":[10, 20]}]}`.

* bits are repositories that were starred by user 1 OR user 2

##### Intersect

Query repositories which have been starred by two users.
```
Intersect(Bitmap(frame="stargazer", user_id=1), Bitmap(frame="stargazer", user_id=2)))
```

Returns `{"results":[{"attrs":{},"bits":[10]}]}`.

* bits are repositories that were starred by user 1 AND user 2

##### Difference

Query repositories which have been starred by one user and not another.
```
Difference(Bitmap(frame="stargazer", user_id=1), Bitmap( frame="stargazer", user_id=2)))
```

Return `{"results":[{"attrs":{},"bits":[30]}]}`

* bits are repositories that were starred by user 1 BUT NOT user 2

```
Difference(Bitmap(frame="stargazer", user_id=2), Bitmap( frame="stargazer", user_id=1)))
```

Return `{"results":[{"attrs":{},"bits":[30]}]}`

* Bits are repositories that were starred by user 2 BUT NOT user 1

##### Count

Query amount repositories that a user contribute to.
```
Count(Bitmap(frame="stargazer", user_id=1))
```

Return `{"results":[2]}`

* Result is the number of repositories that user 1 has starred.

##### TopN

```
TopN(frame="stargazer")
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 2}, {"key": 3, "count": 1}]]}`

* key is a user
* count is amount of repositories
* Results are the number of repositories that each user starred in descending order for all users in the stargazer frame, for example user 1 starred two repositories, user 2 starred two repositories, user 3 starred one repository.

```
TopN(frame="stargazer", n=2)
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 2}]]}`

* Results are the top two users sorted by number of repositories they've starred in descending order.

```
TopN(frame="stargazer", Bitmap(frame="language", id=1), n=2)
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 1}]]}`

* Results are the top two users sorted by the number of repositories that they've starred which are written in language 1.

##### Range Queries

When you set timestamp using SetBit, you will able to query all repositories that a user has starred within a date range.
```
Range(frame="stargazer", user_id=1, start="2017-01-01T00:00", end="2017-03-02T03:04")
```

Returns `{"results":[{"attrs":{},"bits":[10, 20]}]}`

* bits are repositories which were starred by user 1 from 2017-01-01 to 2017-03-02
