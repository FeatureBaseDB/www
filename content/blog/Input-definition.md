+++
date = "2017-08-07"
publishdate = "2017-08-07"
title = "Input Definition"
author = "Michael Baird"
author_img = "0"
image = ""
overlay_color = "green" # blue, green, or light
+++

Pilosa has needed an ETL process to ingest data from various sources, and the Input Definition is our proposed solution.  Please send us your feedback as we further develop this process connecting it to various services.

<!--more-->

As we continue to develop Pilosa we've heard from the community about better methods of ingesting structured data into a Pilosa Index.   Previously the Pilosa API provided a SetBit and bulk Import in our row and column schema.  This is fine when you have the ability to preprocess the raw data, but not when integrating with another service.  Today we are introducing our Import Definition ETL process to manage a JSON data pipeline.  We's envision that at the first step toward build data ingestion integrations with various Lambda architectures.  Please let us know what you think, we appreciate the feedback as we move forward on this roadmap.

Here is the example use case we envisioned when designing this ETL feature.  Lets say you have a data source or service that use JSON as its data protocol.  In Pilosa you would create a input definition in JSON describing how to process this data, and then pass all the data in that format to Pilosa for interpretation.  For example our Stargazer sample data set has information for each Github repo's stargazer in this format:
```
    {
        "language_id": "Go", 
        "repo_id": 91720568, 
        "stargazer_id": 513114
        "time_value": "2017-05-18T20:40"
    }
```

In this dataset some keys like language_id are a string while repo_id and stargazer_id are unique integers, and time_value is date.  Each of these fields can be extracted and translated with a definition for each and value type combination.

To achieve this the Input definition consists of two parts.  First you will need to define a schema for your data.  The schema defines the frames that will store your data in an index.  Frames are used to segment and define different functional characteristics within your entire index.  You can think of a Frame as a table-like data partition within your Index.  Previously you would need to create the frame through a separate API, now it can be done in a single step.  

### Fields
The Fields section of the definition describes the mapping process for each key/value pair within the input data.  There are various methods or `actions` that can be processed per field.  But first the basic structure of a `field` definition.

- `name`: Maps to the source JSON data field name
- `primaryKey`: Must be an unsigned integer which maps directly to a columnID in Pilosa.
- `actions`: This is a list of actions that will process the field's value.

### Actions
A field can have multiple actions that describe the process of mapping a value to a Row ID.  This in conjunction with the `primaryKey` field define the row/column location of the SetBit.  The Action's `frame` must match a one from the schema, and declares the `frame` that will contain our set bits.  

The `fields` array contains a series of JSON objects describing how to process each field received in the input data.  Each `field` object must contain a `name` which maps to the source JSON field name.  One field must be defined at the `primaryKey`.  The `primarykey` source field name must equal the column label for the `Index`, and its value must be an unsigned integer which maps directly to a columnID in Pilosa.

There are several methods for mapping a `field` to a Row ID within an `action`.

- `valueMap`: Define a set of string and integer pairs used to map the field values to a RowID
- `valueDestination`: contains a set of mapping rule for a value
    - `value-to-row`: The value should map directly to a RowID.
    - `single-row-boolean`: If the value is true set a bit using the `rowid`.
    - `mapping`: Map the value to a RowID in the `valueMap`.
- `rowid`: Simply uses a pre-defined SetBit rowID for this field and ignores the value.


Check out the source code in [Input Definition](https://www.pilosa.com/docs/input-definition/) getting started section for an example using this process.

