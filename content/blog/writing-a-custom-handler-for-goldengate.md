+++
date = "2019-02-13"
publishdate = "2019-02-13"
title = "Writing a Custom Handler for Oracle GoldenGate"
author = "Yüce Tekol"
author_twitter = "tklx"
author_img = "4"
image = "/img/blog/ogg-handler.jpg"
overlay_color = "blue" # blue, green, or light
disable_overlay = false
+++

In this post, we will cover creating a custom handler for Oracle GoldenGate which updates the data in a Pilosa server.

<!--more-->

### Introduction

[Oracle GoldenGate](https://www.oracle.com/middleware/technologies/goldengate.html) captures and delivers real-time change data from a compatible database to other databases, data warehouses and applications. The change data is directly read from database logs, having minimal impact on the database itself.

GoldenGate has three primary components:


1. Capture: *Extract groups* retrieve change information from database logs and write it to *trail files*. Since GoldenGate uses the transaction logs from databases, capturing changes has a low impact on the source system.

2. Trail files: A trail file contains changes in a database, such as inserts, updates and deletes in a platfrom independent data format. The changes are ordered by commit time.

3. Delivery: The trail is sent over the network from the source system to the target and written in a remote trail. A replication group applies the changes to the target system. The extract group which reads the local trail and sends the changes is called a *pump*.

In the simplest case, GoldenGate can be used for unidirectional replication from a source to a target. GoldenGate also supports bidirectional and multi-master replication where there may be more than one writer to a database table.

It is possible to extend Oracle GoldenGate's functionality with custom handlers. We are going to use that feature to deliver and map real-time updates from an Oracle database to a Pilosa server using Pilosa Java client library.

[Pilosa](https://www.pilosa.com) is an open source distributed index which enables updating and querying massive data sets in real-time. See the [Pilosa whitepaper (PDF)](https://www.pilosa.com/pdf/PILOSA%20-%20Technical%20White%20Paper.pdf) for more information.

Using GoldenGate with Pilosa has the following benefits:


* Pilosa is distributed and fast. It may be used for a lot of the tasks a database is used for, offloading the tasks to Pilosa and freeing up database resources.
* Using GoldenGate, updates from a database to the Pilosa server can be delivered in a low impact way. GoldenGate extracts changes in the database from logs instead of running queries.
* The data in the database is replicated to a Pilosa server in real-time, making the data in the Pilosa side always up-to-date.

### Getting Ready

Requirements:
* Linux or MacOS, Bash or compatible shell
* Docker 17.05 or better
* Docker Compose
* git

#### Creating Docker Images

Oracle doesn't provide Docker images for their products, but they allow downloading them for evaluation purposes. They supply scripts for creating Docker images from downloaded products.

Clone Oracle Docker Images repository, which contains the necessary scripts to create Docker images for Oracle products:
```
$ git clone https://github.com/oracle/docker-images.git
```

Switch to the `docker-images` directory:
```
$ cd docker-images
```

##### Creating the Oracle Database Image

Create the Oracle Database 12c image (`oracle/database:12.2.0.1-ee`) using the following steps:


1. Switch to `OracleDatabase/SingleInstance/dockerfiles` directory:
    ```
    $ cd OracleDatabase/SingleInstance/dockerfiles
    ```

2. Download Oracle Database 12c Release 2 archive (linuxx64_12201_database.zip) from https://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html and copy it to `12.2.0.1` directory/

3. Run the image creation script:
    ```
    $ ./buildDockerImage.sh -v 12.2.0.1 -e -i
    ```

##### Creating Oracle GoldenGate Images

We need to create two Oracle GoldenGate images:

* Oracle GoldenGate 18 for the `extract` container.
* Oracle GoldenGate for BigData image for the `replicat` container.

First, switch to `OracleGoldenGate` directory:
```
cd ../../../OracleGoldenGate
```

Create the Oracle GoldenGate 18 image using the following steps:


1. Download Oracle GoldenGate 18.1.0.0.0 for Oracle on Linux x86-64 (`181000_fbo_ggs_Linux_x64_shiphome.zip`) from https://www.oracle.com/technetwork/middleware/goldengate/downloads/index.html

2. Run the image creation script:
    ```
    $ BASE_IMAGE=oracle/database:18.3.0-ee ./dockerBuild.sh 181000_fbo_ggs_Linux_x64_shiphome.zip --build-arg BASE_COMMAND="su -c '/opt/oracle/runOracle.sh' oracle" --tag oracle/db-18.3-goldengate-standard:18.1.0.0.0
    ```

Create the GoldenGate for BigData image using the following steps:


1. Download Oracle GoldenGate for Big Data 12.3.2.1.1 on Linux x86-64 (`OGG_BigData_Linux_x64_12.3.2.1.1.zip`) from https://www.oracle.com/technetwork/middleware/goldengate/downloads/index.html

2. Run the image creation script:
    ```
    BASE_IMAGE="oraclelinux:7-slim" ./dockerBuild.sh OGG_BigData_Linux_x64_12.3.2.1.1.zip --tag oracle/goldengate-standard-bigdata:12.3.0.1.2
    ```

##### Patching the Oracle Database Image

After completing the *Creating the Oracle GoldenGate Image* section above, we should end up with the `oracle/db-12.2-goldengate-standard:18.1.0.0.0` image. The `root` user in the created image doesn't have the correct [PAM](http://www.linux-pam.org) so we need to add them. The simplest way of doing it is creating another Docker image based on the image we have created.


1. Clone https://github.com/pilosa/sample-ogg-handler to somewhere in your system.
2. Switch to the `sample-ogg-handler/docker` directory.
3. Run the following to create the patched image:
    ```
    $ docker build -t oracle/db-12.2-goldengate-standard:18.1.0.0.0-patched .
    ```

### Running the Setup

The sample setup is composed of an Oracle database container, the replication container which also contains the custom adapter, and a Pilosa container.

We have already cloned the sample project in the *Patching the Oracle Database Image* section. The sample project includes a Docker compose file. Let's run it:
    ```
    $ docker-compose up
    ```

This takes a while.

Before carrying on with enabling GoldenGate support, we have to modify the `tnsnames.ora` file which contains database service names mapped to listener protocol addresses. The default installed one doesn't seem to be in the correct format:
```
$ docker exec -it sampleogghandler_extract_1 cp /prv/tnsnames.ora /opt/oracle/oradata/dbconfig/ORCLCDB/tnsnames.ora
```

Make sure running the following commands end with `OK`:

* `docker exec -it sampleogghandler_extract_1 tnsping ORCLCDB`
* `docker exec -it sampleogghandler_extract_1 tnsping ORCLPDB1`

#### Enabling GoldenGate Support on an Oracle Database

The support for GoldenGate is not enabled on Oracle databases by default. Follow the steps below to enable it:


1. Start a shell on the extract container with the `oracle` user:
    ```
    $ docker exec -it sampleogghandler_extract_1 su oracle
    ```

2. Prepare the root database.

    Login to the root database:
    ```
    $ sqlplus / as SYSDBA
    ```

    Turn on the archive log:
    ```
    SHUTDOWN IMMEDIATE;
    STARTUP MOUNT EXCLUSIVE;
    ALTER DATABASE ARCHIVELOG;
    ALTER DATABASE OPEN;
    ```

    This may take a while.

    Create the extract user. The user must be added to the root database when the integrated mode is used:
    ```
    CREATE USER c##ggadmin IDENTIFIED BY w
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp;
    GRANT DBA TO c##ggadmin container=all;
    EXEC dbms_goldengate_auth.grant_admin_privilege('c##ggadmin',container=>'all');
    ```

    Check whether GoldenGate replication was enabled on this database:
    ```
    SHOW PARAMETER ENABLE_GOLDENGATE_REPLICATION;
    ```

    If it is not already enabled, enable it:
    ```
    ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=true SCOPE=both;
    ```

    Chech whether supplemental logging is enabled:
    ```
    SELECT SUPPLEMENTAL_LOG_DATA_MIN, FORCE_LOGGING FROM v$database;
    ```

    If it is not already enabled, enable it:
    ```
    ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
    ALTER DATABASE FORCE LOGGING;
    ALTER SYSTEM SWITCH LOGFILE;
    ```

    Exit `sqlplus` using `Ctrl+D`.

3. Next, let's prepare the pluggable database:

    Login to the pluggable database:
    ```
    $ sqlplus SYS/w@ORCLPDB1 as SYSDBA
    ```

    Create the schema:
    ```
    CREATE USER ogguser IDENTIFIED BY w;
    GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE, CREATE VIEW TO ogguser;
    ```

    Exit `sqlplus` using `Ctrl+D`.

4. Create demo tables:
    ```
    $ echo EXIT | sqlplus ogguser@ORCLPDB1/w @$ORACLE_HOME/demo/schema/human_resources/hr_cre.sql
    ```

5. Create the GoldenGate credentials store and add the user for extract:

    Start GoldenGate console:
    ```
    $ ggsci
    ```

    Add a credential store and store the root database user credentials:
    ```
    ADD CREDENTIALSTORE
    ALTER CREDENTIALSTORE ADD USER c##ggadmin@ORCLCDB PASSWORD w ALIAS c##ggadmin
    ```

6. Enable schema-level supplemental logging for the database tables:
    ```
    DBLOGIN USERIDALIAS c##ggadmin
    ADD SCHEMATRANDATA ORCLPDB1.ogguser
    ```

#### Setting Up Extract and Pump Groups

While still in the GoldenGate console, follow these steps to create and start extract and pump groups.

1. The extract group is used to obtain the changes from the database log and save it to the trail file. Let's add it.

    Check the contents of the extract group:
    ```
    VIEW PARAM ext
    ```

    Outputs:
    ```
    EXTRACT ext
    SETENV (ORACLE_SID = ORCLCDB)
    USERIDALIAS c##ggadmin
    EXTTRAIL ./dirdat/et
    GETUPDATEBEFORES
    UPDATERECORDFORMAT COMPACT

    SOURCECATALOG ORCLPDB1
    TABLE ogguser.*;
    SEQUENCE ogguser.*;
    ```

    Add the extract group. We limit each trail file to be at most 5 megabytes; that's adequate for the sample project.
    ```
    ADD EXTRACT ext, INTEGRATED TRANLOG, BEGIN NOW
    ADD EXTTRAIL ./dirdat/et, EXTRACT ext, MEGABYTES 5
    ```

    Register the extract group with the pluggable database:
    ```
    REGISTER EXTRACT ext DATABASE CONTAINER (ORCLPDB1)
    ```

    This may take a while to complete.

    Check that extract group is present:
    ```
    INFO EXTRACT ext
    ```

    Should output something like:
    ```
    EXTRACT    EXT       Initialized   2019-02-07 14:29   Status STOPPED
    Checkpoint Lag       00:00:00 (updated 00:01:20 ago)
    Log Read Checkpoint  Oracle Integrated Redo Logs
                        2019-02-07 14:29:08
                        SCN 0.0 (0)
    ```

2. The pump group is used to send the local trail to a remote location over the network, in our case the `replicat` container.

    Check the contents of the pump group:
    ```
    VIEW PARAM pump
    ```

    Outputs:
    ```
    EXTRACT pump
    RMTHOST replicat, MGRPORT 7809, COMPRESS
    RMTTRAIL ./dirdat/pm
    PASSTHRU

    SOURCECATALOG ORCLPDB1
    TABLE ogguser.*;
    SEQUENCE ogguser.*;
    ```

    Using our Docker compose setup, the replicat container is accessible with the host name `replicat`. We set the trail format to `12.1` for the pump too.

    Add the pump group.
    ```
    ADD EXTRACT pump, EXTTRAILSOURCE ./dirdat/et
    ADD RMTTRAIL ./dirdat/pm, EXTRACT pump, MEGABYTES 5
    ```

3. Start the extract and pump groups:
    ```
    START EXTRACT EXT
    START EXTRACT PUMP
    ```

    Check that the extract groups are running:
    ```
    INFO ALL
    ```

    Should output something like:
    ```
    Program     Status      Group       Lag at Chkpt  Time Since Chkpt

    MANAGER     RUNNING
    EXTRACT     RUNNING     EXT         00:32:27      00:00:04
    EXTRACT     RUNNING     PUMP        00:00:00      00:00:08
    ```

    If any of the items in that list has `STOPPED` or `ABENDED` status, check the logs for errors using `VIEW REPORT GROUP_NAME`, e.g., for `ext`:
    ```
    VIEW REPORT ext
    ```

#### Setting Up the Pilosa Handler Project

We are going to take a detour to set up the custom handler project here.

Requirements:

* JDK 1.8
* Maven 3.6 or better

A sample Pilosa handler for GoldenGate is included in the `handler` directory in `sample-ogg-handler` that we cloned earlier.

1. You have already downloaded `OGG_BigData_Linux_x64_12.3.2.1.1.zip` before. Extract `OGG_BigData_Linux_x64_12.3.2.1.1.tar` from `OGG_BigData_Linux_x64_12.3.2.1.1.zip`.

2. Extract `ggjava` directory from `OGG_BigData_Linux_x64_12.3.2.1.1.tarr` and copy it to `local` directory of `handler`, so `handler/local/ggjava` directory contains the GoldenGate libraries.

3. In a shell, register the libraries for the GoldenGate Java Adapter. This has to be done only once:
    ```
    $ make install-libs
    ```

4. In order to build the project, run `make`. If there are no errors, you should end up with `target/sample-ogg-handler-0.1.0-all.jar`. This file contains everything needed to run the handler.

5. Copy `target/sample-ogg-handler-0.1.0-all.jar` to the `v_dirprm/handler` directory in `sample-ogg-handler`. We  will need to do that whenever we modify the handler.

6. You can open the GoldenGate handler project in the `handler` directory with your favorite IDE/editor and check the contents of `src\main\java\sample\GoldengateHandler.java`. This is the source file that contains all the logic for the handler.

#### Setting Up Replication

Our custom handler will run in the replicat container and react to the changes to the trail file. The trail file is updated using the data sent by the pump in the extract container.

1. Run a shell in the replicat container using the `oracle` user:
    ```
    $ docker exec -it sampleogghandler_replicat_1 su oracle
    ```

2. Check that properties for the custom handler are correct:

    ```
    $ cat dirprm/pilosa.properties
    ```

    Should output:
    ```
    gg.log = log4j
    gg.log.level = info
    gg.classpath = dirprm/handler/sample-ogg-handler-0.1.0-all.jar
    gg.handlerlist = pilosa

    gg.handler.pilosa.type = sample.PilosaHandler
    gg.handler.pilosa.address = pilosa:10101
    ```

    The properties file contains settings for the custom handler. Most of the entries in the properties file should be self-explanatory. The most import entries are:
    * `gg.classpath` should contain the class path for the handler. You can specify a comma delimited list of directories and jar files.
    * `gg.handlerlist` should contain a comma delimited list of handler names. You can choose any name you would like, but it should match the entries for other settings for the handler.
    * `gg.handler.HANDLER_NAME.type` should contain the complete name of the handler, including the package name.
    * `gg.handler.HANDLER_NAME.address` is a setting directly passed to `setAddress` method of `sample.PilosaHandler`.

    The name of the properties file is the same as the extract group we will be adding next, so it is found automatically.

3. Replicat groups process a trail file and apply the changes to a database, or execute a handler in our case.

    Run the GoldenGate console:
    ```
    $ ggsci
    ```

    The replicat params are in `dirprm/pilosa.prm`. Verify that it's there:
    ```
    VIEW PARAM pilosa
    ```

    Should output:
    ```
    REPLICAT pilosa
    TARGETDB LIBFILE libggjava.so
    REPORTCOUNT EVERY 1 MINUTES, RATE
    GROUPTRANSOPS 1000
    MAP ORCLPDB1.ogguser.*, TARGET ogguser.*;
    ```

    Add the replicat group:
    ```
    ADD REPLICAT pilosa, EXTTRAIL ./dirdat/pm, NODBCHECKPOINT
    ```

    Check that the extract group was created:

    ```
    INFO ALL
    ```

    Should output something like:
    ```
    Program     Status      Group       Lag at Chkpt  Time Since Chkpt

    MANAGER     RUNNING
    REPLICAT    STOPPED     PILOSA      00:00:00      00:00:01
    ```

    Start the replicat group:
    ```
    START REPLICAT pilosa
    ```

    Check that the extract group is running:
    ```
    info all
    ```

    Should output something like:
    ```
    Program     Status      Group       Lag at Chkpt  Time Since Chkpt

    MANAGER     RUNNING
    REPLICAT    RUNNING     PILOSA      00:00:00      00:00:05
    ```

    If the group has `STOPPED` or `ABENDED` status, check the logs for errors using:
    ```
    VIEW REPORT pilosa
    ```

12. View the custom handler logs:
    ```
    VIEW REPORT pilosa
    ```

    TThe replicat container log is located at: `dirrpt/PILOSA_info_log4j.log`

#### Insert Data to the Source Database

Start a shell on the Pilosa container with `oracle` user:
```
$ docker exec -it sampleogghandler_extract_1 su oracle
```

Insert sample records into the source database:
```
$ echo EXIT | sqlplus ogguser@ORCLPDB1/w @$ORACLE_HOME/demo/schema/human_resources/hr_popul.sql
```

#### Check the Data on the Pilosa Side

Let's confirm the data on the Pilosa side was updated when we inserted some records to the source database.

Start a shell on the Pilosa container:
```
$ docker exec -it sampleogghandler_pilosa_1 sh
```

Let's find out what are the top 5 jobs and the number of employees having those jobs:
```
# curl pilosa:10101/index/employees/query -d 'TopN(job, Row(ok=true), n=5)'
```

Turns out there are 30 sales representatives, 20 shipping clerks, etc.:
```
{"results":[[{"id":0,"key":"SA_REP","count":30},{"id":0,"key":"SH_CLERK","count":20},{"id":0,"key":"ST_CLERK","count":20},{"id":0,"key":"FI_ACCOUNT","count":5},{"id":0,"key":"SA_MAN","count":5}]]}
```

Which sales representatives earn $10000 or more and what do we know about them?
```
# curl pilosa:10101/index/employees/query -d 'Options(Intersect(Row(ok=true), Row(salary >= 10000), Row(job="SA_REP")), columnAttrs=true)'
```

Outputs:
```
{"results":[{"attrs":{},"columns":[150,156,162,168,169,174]}],"columnAttrs":[{"id":150,"attrs":{"email":"PTUCKER"}},{"id":156,"attrs":{"email":"JKING"}},{"id":162,"attrs":{"email":"CVISHNEY"}},{"id":168,"attrs":{"email":"LOZER"}},{"id":169,"attrs":{"email":"HBLOOM"}},{"id":174,"attrs":{"email":"EABEL"}}]}
```

Let's delete one of the employees from the source table to confirm that the corresponding column is marked non-existent.

Open `sqlplus`:
```
$ docker exec -it sampleogghandler_extract_1 su oracle -c 'sqlplus ogguser@ORCLPDB1/w'
```

Delete the employee with ID 150, who is a sales representative:
```
DELETE FROM ogguser.employees WHERE employee_id=150;
COMMIT;
```

How many sales representatives left?
```
 # curl pilosa:10101/index/employees/query -d 'Count(Intersect(Row(ok=true), Row(job="SA_REP")))'
```

Outputs:
```
{"results":[29]}
```

Check out our [documentation](https://www.pilosa.com/docs/latest/query-language/) for PQL, the query language of Pilosa, for more.

### Conclusion

In this article we explored how to write a custom handler for Oracle GoldenGate, specifically a Pilosa handler. GoldenGate custom handlers enable acting on trail files in an efficient and fast way.

We are developing a Pilosa adapter for Oracle GoldenGate, which provides a Javascript based API for programming the translation logic. It is still in early phase of development, but [let us know](https://www.pilosa.com/about/#contact) if you are interested in integrating Pilosa in your workflow or providing feedback.

_Yüce is an Independent Software Engineer at Pilosa. When he's not writing Pilosa client libraries, you can find him watching good bad movies. He is [@yuce](https://github.com/yuce) on GitHub and [@tklx](https://twitter.com/tklx) on Twitter._
