minikube  start --memory 16384 --cpus 6 --disk-size 80000mb

kubectl apply -k kustomize/install/namespace
kubectl apply --server-side -k kustomize/install/default
kubectl apply -k kustomize/high-availability/

PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n postgres-operator -o name \
  -l postgres-operator.crunchydata.com/cluster=hippo-ha,postgres-operator.crunchydata.com/role=master)

kubectl exec --stdin -n postgres-operator --tty "${PG_CLUSTER_PRIMARY_POD}" -- /bin/bash

psql -c "CREATE DATABASE testdb"

pgbench -i -s 200 testdb

exit

# Check, that the a full backup of the previously created database exists
kubectl exec --stdin -n postgres-operator --tty  hippo-ha-repo-host-0 -- /bin/bash
pgbackrest info

exit

kubectl exec --stdin -n postgres-operator --tty "${PG_CLUSTER_PRIMARY_POD}" -- /bin/bash

psql -c "SELECT current_timestamp, pg_size_pretty(pg_database_size('testdb'))"
       current_timestamp       | pg_size_pretty 
-------------------------------+----------------
2022-09-26 13:06:09.536499+00 | 2999 MB
(1 row)


# psql -c "DROP TABLE public.pgbench_history" testdb
psql -c "DROP DATABASE testdb"

exit

# Add timestamp to ha-postgresql.yaml and set enabled=true

kubectl apply -k kustomize/high-availability/

kubectl annotate -n postgres-operator postgrescluster hippo-ha --overwrite \
  postgres-operator.crunchydata.com/pgbackrest-restore=id1

# Check if the dropped table has been restored


PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n postgres-operator -o name \
  -l postgres-operator.crunchydata.com/cluster=hippo-ha,postgres-operator.crunchydata.com/role=master)

kubectl exec --stdin -n postgres-operator --tty "${PG_CLUSTER_PRIMARY_POD}" -- /bin/bash


psql -c "\d" testdb
              List of relations
 Schema |       Name       | Type  |  Owner   
--------+------------------+-------+----------
 public | pgbench_accounts | table | postgres
 public | pgbench_branches | table | postgres
 public | pgbench_tellers  | table | postgres

# Table pgbench_history has not been restored!!!

exit

# Export log files
