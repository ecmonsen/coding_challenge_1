-- SQL from the original problem description
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


-- table used to maintain the top-level parent of each sample. Rows are inserted using the `etl.py` script
create table sample_tree(
    sample_id int primary key,
    root_id int not null,
    path varchar(1000));

create table etl_runs(
    -- row id
    id int primary key auto_increment,
    -- when the ETL was run (for logging purposes)
    run_ts timestamp not null default CURRENT_TIMESTAMP,
    -- the maximum value encountered for `ts` from the samples table
    max_sample_ts timestamp not null);

-- a single row view with the latest timestamp to be processed. This is used in cross joins during ETL.
create view view_latest_processed_ts as
    select coalesce(max(max_sample_ts),cast('2000-01-01 00:00:00' as datetime)) as latest_processed_ts from etl_runs;

-- Transform `sample` and `sample_tree` rows into a client friendly format.
create view view_client_results
as
select experiment_id, root_id as top_parent_id,
       id as sample_id, sm_vol.value as measurement_vol,
       sm_ph.value as measurement_ph
from samples s
    join sample_tree t on s.id=t.sample_id
-- the "measurement_vol" column comes from:
left join sample_measurements sm_vol on s.id = sm_vol.sample_id and sm_vol.measurement_type='vol'
-- the "measurement_ph" column comes from:
left join sample_measurements sm_ph on s.id=sm_ph.sample_id and sm_ph.measurement_type='ph';
