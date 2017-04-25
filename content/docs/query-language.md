+++
title = "Query Language"
+++

# Query Language

Make sure an index and frame are created before running a query as discussed in [Getting Started](getting_started).

Let’s use the following schemas for an example:
```
Index: repository
    col: repo_id
    frame: stargazer
        row: user_id
    frame: language
        row: language_id (C, Go, Java, Python)
```

This index can serve queries like:

* To how many repositories has user 1 contributed?
* How many repositories are written in the Go programming language?
* What are the top five users who have contributed to the most repositories?
* What are the top five users who have contributed to the most repositories that are written in Go?
* To how many repositories have both user 1 and user 2 contributed?
* How many repositories has user 1 worked on that user 2 has not?

```
Index: user
    col: user_id
    frame: repositories
        row: repo_id
    frame: geo
        row: country_id
```

This index can serve queries like:

* How many users have contributed to repository 1?
* How many users are from location 1?
* What are the top five repositories to which the most users have contributed?
* How many users have contributed to project 1 but not project 2?
* How many users have contribute to both project 1 and project 2?

## Setting and Clearing Bits

### SetBit

SetBit(), as the name implies, assigns a value of 1 to a bit in the binary matrix, thus associating the given row in the given frame with the given column.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'SetBit(frame="stargazer", repo_id=10, user_id=1)'
```

This query illustrates setting a bit in the stargazer frame of the repository index. User with id=1 has starred repository with id=10.

Setbit also supports providing a timestamp. To write the date that a user starred a repository.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'SetBit(frame="stargazer", repo_id=10, user_id=1, timestamp="2016-01-01T00:00")'
```

You can set multiple bits:
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'SetBit(frame="stargazer", repo_id=10, user_id=1) SetBit(frame="stargazer", repo_id=10, user_id=2) SetBit(frame="stargazer", repo_id=20, user_id=1) SetBit(frame="stargazer", repo_id=30, user_id=2)`
```

A return value of `{"results":[true]}` indicates that the bit was changed to 1.

A return value of `{"results":[false]}` indicates that the bit was already set to 1 and nothing changed.

### SetBitmapAttrs

SetBitmapAttrs() supports writing attributes of the Row. 
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'SetBitmapAttrs(frame="stargazer", user_id=10, username="mrpi", active=true)'
```

Set username value and active status for user = 10. These are arbitrary key/value pairs which have no meaning to Pilosa.

SetBitmapAttrs queries always return  {"results":[null]} upon success.

### SetColumnAttrs

SetColumnAttrs() supports writing attributes of the Column. 
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'SetColumnAttrs(frame="stargazer", repo_id=10, stars=123, url="http://projects.pilosa.com/10", active=true)'
```

Set url value and active status for project 10. These are arbitrary key/value pairs which have no meaning to Pilosa.

SetColumnAttrs queries always return {"results":[null]} upon success.

### ClearBit

```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'ClearBit(frame="stargazer", repo_id=10, user_id=1)'
```

Remove relationship between user_id=1 and repo_id=10  from the "stargazer" frame in the "repository" index.

A return value of `{"results":[true]}` indicates that the bit was toggled from 1 to 0.

A return value of `{"results":[false]}` indicates that the bit was already set to 0 and nothing changed.

## Bitwise Operations

### Bitmap

Query all repositories that user 1 has starred.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'Bitmap(frame="stargazer", user_id=1)'
```

Returns `{"results":[{"attrs":{"username":"mrpi","active":true},"bits":[10, 20]}]}`

* attrs are the attributes for user 1 
* bits are the repositories which user 1 has starred.

### Union

Query all repositories that are contributed by multiple users
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d  'Union(Bitmap(frame="stargazer", user_id=1), Bitmap(frame="stargazer", user_id=2)))'
```

Returns `{"results":[{"attrs":{},"bits":[10, 20]}]}`.

* bits are repositories that were starred by user 1 OR user 2

### Intersect

Query repositories which have been starred by two users.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'Intersect(Bitmap(frame="stargazer", user_id=1), Bitmap(frame="stargazer", user_id=2)))'
```

Returns `{"results":[{"attrs":{},"bits":[10]}]}`.

* bits are repositories that were starred by user 1 AND user 2

### Difference

Query repositories which have been starred by one user and not another.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d  'Difference(Bitmap(frame="stargazer", user_id=1), Bitmap( frame="stargazer", user_id=2)))'
```

Return `{"results":[{"attrs":{},"bits":[30]}]}`

* bits are repositories that were starred by user 1 BUT NOT user 2

```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d  'Difference(Bitmap(frame="stargazer", user_id=2), Bitmap( frame="stargazer", user_id=1)))'
```

Return `{"results":[{"attrs":{},"bits":[30]}]}`

* Bits are repositories that were starred by user 2 BUT NOT user 1

### Count

Query amount repositories that a user contribute to.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 'Count(Bitmap(frame="stargazer", user_id=1))'
```

Return `{"results":[2]}`

* Result is the number of repositories that user 1 has starred.

### TopN

```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d 
'TopN(frame="stargazer")'
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 2}, {"key": 3, "count": 1}]]}`

* key is a user
* count is amount of repositories
* Results are the number of repositories that each user starred in descending order for all users in the stargazer frame, for example user 1 starred two repositories, user 2 starred two repositories, user 3 starred one repository.

```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d
'TopN(frame="stargazer", n=2)'
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 2}]]}`

* Results are the top two users sorted by number of repositories they've starred in descending order.

```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d
'TopN(frame="stargazer", Bitmap(frame="language", id=1), n=2)'
```

Returns `{results: [[{"key": 1, "count": 2}, {"key": 2, "count": 1}]]}`

* Results are the top two users sorted by the number of repositories that they've starred which are written in language 1.

### Range Queries

When you set timestamp using SetBit, you will able to query all repositories that a user has starred within a date range.
```
curl -X POST "http://127.0.0.1:10101/query?db=repository" -d
'Range(frame="stargazer", user_id=1, start="2017-01-01T00:00", end="2017-03-02T03:04")'
```

Returns `{"results":[{"attrs":{},"bits":[10, 20]}]}`

* bits are repositories which were starred by user 1 from 2017-01-01 to 2017-03-02
