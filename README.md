# Coding Challenge Response

## Original Request
```
--- Task 1
--- experimental data in DB ----
Given the SQL script below (runs in MYSQL), please create an ETL process that will maintain and populate a view or a table “experiment_measurements” with following columns
experiment_id - from the samples 
top_parent_id - samples.id from samples where parent_id is null 
sample_id - sample id which has measurements attached 
mesurement_vol, measurement_ph - columns created dynamically based on values in ‘measurement_type’

Expected to provide this data to our customers 
|experiment_id|top_parent_id|sample_id|mesurement_vol|measurement_ph|
|1            |1            | 17      | 10.2         | 5.0          |
|1            |5            | 8       | 40.          | 7.4          | 

Please consider:
Number of samples is growing daily and already in millions 
Number of levels in the tree could be limited by 1000
New types of measurements can be added/removed occasionally 

Please DO NOT USE Stored procedures to solve this problem. The solution DOES NOT have to use any RDBMS. We provide SQL only for convenience. 

Small data sample below: 
----------------------------------------
create table samples(id int primary key auto_increment, parent_id int, experiment_id int, ts timestamp not null default CURRENT_TIMESTAMP, foreign key(parent_id) references samples(id) on delete cascade);
create table sample_measurements(sample_id int, measurement_type varchar(10), value decimal(16,6), foreign key(sample_id) references samples(id) on delete cascade);

insert into samples  (parent_id, experiment_id) values
(null, 1), (1,1), (1,1), (1,1),
(null, 1), (2,1), (5,1), (7,1),
(2, 1), (9,1), (10,1), (9,1),
(null, 2), (13,2), (13,2), (13,2),
(10, 1), (17,1), (17,1), (11,1);

insert into sample_measurements values
(2, 'vol', 500), (3, 'vol', 400),
(6, 'vol', 51), (9, 'vol', 50),
(10, 'vol', 10.5), (12, 'vol', 40.3),
(17, 'vol', 10.2), (8, 'vol', 40.8),
(19, 'vol', 10), (20, 'vol', 40.7),
(2, 'ph', 5.0), (3, 'ph', 7.0),
(6, 'ph', 5.1), (9, 'ph', 7.2),
(10, 'ph', 5.2), (12, 'ph', 7.4),
(17, 'ph', 5.0), (8, 'ph', 7.4),
(19, 'ph', 5.25), (20, 'ph', 7.34);
```
## Response
This response consists of a SQL script, a Python ETL script, and the scaffolding needed to run it.

Essentially this process will maintain a new table, `sample_tree`, which tracks the top-level parent (aka root) of each sample, and uses a SQL view to present results in the requested format.

Because this is a coding exercise, many shortcuts were taken in regards to the database, such as hard-coded passwords.

### SQL

From the original problem statement: `samples`, `sample_measurements`

Solution tables in [01_create_tables.sql](./mysql_ddl/01_create_tables.sql)
* `sample_tree` tracks the "top parent" or root sample id for each sample. This is so that the tree is traversed only once (or less) for each sample.
* `etl_runs` tracks the latest `sample.ts` timestamp to be processed. This is so that most sample rows are only processed once.
  * In an edge case, a row with `sample.ts` exactly equal to the maximum value in `etl_runs` might be "seen" by the ETL more than once. But the ETL script will not process rows already seen.
* `view_client_results` performs joins to select results from `samples` and `sample_tree` in the requested format.
    
### Python ETL script

[etl.py](./etl.py) contains the algorithm for ingesting new data in `samples`.

In a production ETL system, it would be run on a recurring basis, e.g. as a cron job.

The algorithm is as follows:

For rows in `sample` that have a `ts` equal to or later than the maximum `ts` processed in the last run:
1. Insert any new top-parent / root  samples into `sample_tree`
2. Insert samples into `sample_tree` whose parent already appears in `sample_tree`
3. Repeat step 2 until all samples appear in `sample_tree`

### Show results

`bash get_client_results.py` will execute a SQL query to show results in the form requested. 

## Running the project

### Requirements:
* Docker
* Python 3.8

1. Create Python virtual environment
   1. `python -m venv venv`
   1. `. venv/bin/activate`
   1. `pip install -r requirements.txt`
1. Start MySQL in a Docker container with `docker-compose up`
1. Run the ETL script, `python etl.py`
1. Run the results script `bash get_client_results.py`
  
### Results from sample data

This is the result produced given the sample data:

```
+---------------+---------------+-----------+-----------------+----------------+
| experiment_id | top_parent_id | sample_id | measurement_vol | measurement_ph |
+---------------+---------------+-----------+-----------------+----------------+
|             1 |             1 |         1 |            NULL |           NULL |
|             1 |             1 |         2 |      500.000000 |       5.000000 |
|             1 |             1 |         3 |      400.000000 |       7.000000 |
|             1 |             1 |         4 |            NULL |           NULL |
|             1 |             5 |         5 |            NULL |           NULL |
|             1 |             1 |         6 |       51.000000 |       5.100000 |
|             1 |             5 |         7 |            NULL |           NULL |
|             1 |             5 |         8 |       40.800000 |       7.400000 |
|             1 |             1 |         9 |       50.000000 |       7.200000 |
|             1 |             1 |        10 |       10.500000 |       5.200000 |
|             1 |             1 |        11 |            NULL |           NULL |
|             1 |             1 |        12 |       40.300000 |       7.400000 |
|             2 |            13 |        13 |            NULL |           NULL |
|             2 |            13 |        14 |            NULL |           NULL |
|             2 |            13 |        15 |            NULL |           NULL |
|             2 |            13 |        16 |            NULL |           NULL |
|             1 |             1 |        17 |       10.200000 |       5.000000 |
|             1 |             1 |        18 |            NULL |           NULL |
|             1 |             1 |        19 |       10.000000 |       5.250000 |
|             1 |             1 |        20 |       40.700000 |       7.340000 |
+---------------+---------------+-----------+-----------------+----------------+

```