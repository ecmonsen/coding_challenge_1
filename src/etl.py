# This is the ETL process to ingest new sample rows.

import mysql.connector
import sys

sql_insert_roots = """
insert into sample_tree (sample_id, root_id, path)
select id, id, cast(id as char)
from samples s
cross join view_latest_processed_ts
left join sample_tree t on s.id = t.sample_id
-- exclude roots that might have already been added
where parent_id is null and t.sample_id is null
-- for performance, only look at rows occurring at or after the last processed timestamp
-- (edge case: this may include rows that were already processed if ts == latest_processed_ts)
and ts >= latest_processed_ts
"""

sql_insert_children = """
insert into sample_tree
select child.id,
       parent_tree.root_id,
       concat(parent_tree.path,'.', cast(child.id as char))
from (select * from samples cross join view_latest_processed_ts) child
join samples parent on child.parent_id=parent.id
left join sample_tree child_tree on child_tree.sample_id=child.id
left join sample_tree parent_tree on parent_tree.sample_id=parent.id
where child_tree.sample_id is null
and parent_tree.sample_id is not null
and child.ts >= latest_processed_ts
"""

sql_insert_etl_run = """
insert into etl_runs (max_sample_ts) select max(ts) from samples
"""

sql_get_results = "select * from view_client_results"

with mysql.connector.connect(
        user='meva', password='meva', host='db', port=3306, database='meva1') as conn:
        # Replace the line above with this one to run this outside of a Docker image
        #        user='meva', password='meva', host='127.0.0.1', port=3310, database='meva1') as conn:
    with conn.cursor() as cursor:
        try:
            # insert any new top parents
            print("Adding root nodes")
            cursor.execute(sql_insert_roots)
            # insert new children (TODO: Loop)
            print("Adding first descendants of root nodes")
            cursor.execute(sql_insert_children)
            while cursor.rowcount>0:
                print("Adding more descendants of root nodes")
                cursor.execute(sql_insert_children)
            # Insert last processed TS into etl_runs
            cursor.execute(sql_insert_etl_run)

            # For demonstration, select and show the results (this would not normally be an ETL component)
            cursor.execute(sql_get_results)
            result = cursor.fetchall()
            print("\t".join(cursor.column_names))
            print("\n".join(["\t".join([str(item) for item in list(r)]) for r in result]))
        except Exception as e:
            # Rolling back in case of error
            conn.rollback()
            # Really simple error messaging. Proper ETL would have forensic info, retries etc.
            print("Error occurred. Rolling back.", file=sys.stderr)
            print(str(e), file=sys.stderr)
        # Closing the connection
