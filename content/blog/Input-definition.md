+++
date = "2017-08-07"
publishdate = "2017-08-07"
title = "Input Definition"
author = "Michael Baird"
author_img = "0"
image = ""
overlay_color = "green" # blue, green, or light
+++

Pilosa has needed an ETL (extract transform load) process to integrate with various data sources, and the Input Definition is our proposed solution. Please send us your feedback as we continue building ways to connect Pilosa with other services.

<!--more-->

Historically the Pilosa API provided a SetBit and bulk Import to preprocess and ingest raw data. Today we are introducing our Import Definition ETL process to manage a JSON data pipeline as the first step toward integrations with various Lambda architectures. Please let us know what you think, we appreciate the feedback as we explore solutions in this area.

Here is the example use case we envisioned when designing this ETL feature. Let's say you have a data source or service that uses JSON as its data protocol. In Pilosa you would create an Input Definition in JSON describing how to process this data, and then pass all the data in that format to Pilosa for interpretation. For example our Stargazer sample data set has information for each Github repo's stargazer in this format:
```
    {
        "language_id": "Go", 
        "repo_id": 91720568, 
        "stargazer_id": 513114
        "time_value": "2017-05-18T20:40"
    }
```

In this dataset, some keys represent string values (`language_id`), while others represent unique integers (`repo_id`, `stargazer_id`) and dates (`time_value`). The Input Definition defines how to transform each of these key/value pair types into SetBits.

The Input Definition consists of two parts: a schema and a list of field mapping rules. The schema defines the frames that will store your data in an index. The `fields` define how to process each key/value into a SetBit.

### Fields
The Fields section of the definition describes the mapping process for each key/value pair within the input data. While there are various methods or `actions` that can be processed per field, the basic structure of a field definition looks like this:

- `name`: Maps to the name of the field in the JSON source data.
- `primaryKey`: An unsigned integer which maps directly to a ColumnID in Pilosa.
- `actions`: A list of actions that will process the field's value.

### Actions
A field can have multiple actions that describe the process of mapping a value to a RowID. Each action, in conjunction with the primaryKey field, defines a row/column location of a SetBit. The Action's `frame` value, which declares the `frame` that will contain our set bits, must match a `frame` defined in the schema.

The `fields` array contains a series of JSON objects describing how to process each field received in the input data. Each `field` object must contain a `name` which maps to the source JSON field name. One field must be defined at the `primaryKey`. The `primarykey` source field name must equal the column label for the `Index`, and its value must be an unsigned integer which maps directly to a ColumnID in Pilosa.

There are several methods for mapping a `field` to a RowID within an `action`.

- `valueMap`: Defines a set of string and integer key/value pairs mapping a source value to a RowID.
- `valueDestination`: Contains a set of mapping rules for a source value.
    - `value-to-row`: Maps a source value directly to a RowID.
    - `single-row-boolean`: Maps a boolean value to a static `RowID`.
    - `mapping`: Maps the source value to a RowID referencing another `valueMap`.
- `RowID `: Uses a static SetBit RowID, and ignores the source value.


Check out the source code in [Input Definition](https://www.pilosa.com/docs/input-definition/) within our [Getting Started](https://www.pilosa.com/docs/getting-started/) section for an example using this process.
