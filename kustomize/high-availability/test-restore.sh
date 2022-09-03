minikube  start --memory 16384 --cpus 6 --disk-size 80000mb

kubectl apply -k kustomize/install/namespace
kubectl apply --server-side -k kustomize/install/default
kubectl apply -k kustomize/high-availability/

PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n postgres-operator -o name \
  -l postgres-operator.crunchydata.com/cluster=hippo-ha,postgres-operator.crunchydata.com/role=master)

kubectl exec --stdin -n postgres-operator --tty "${PG_CLUSTER_PRIMARY_POD}" -- /bin/bash

psql -c "CREATE DATABASE testdb"

pgbench -i -s 200 testdb

psql -c "SELECT current_timestamp, pg_size_pretty(pg_database_size('testdb'))"
       current_timestamp       | pg_size_pretty 
-------------------------------+----------------
2022-09-03 05:57:41.563908+00 | 2999 MB
(1 row)

exit

# Check, that the a full backup of the previously created database exists
kubectl exec --stdin -n postgres-operator --tty  hippo-ha-repo-host-0 -- /bin/bash
pgbackrest info

exit

kubectl exec --stdin -n postgres-operator --tty "${PG_CLUSTER_PRIMARY_POD}" -- /bin/bash

psql -c "DROP TABLE public.pgbench_history" testdb

exit

# Add timestamp to ha-postgresql.yaml and set enabled=true

# kubectl apply -k kustomize/high-availability/

kubectl annotate -n postgres-operator postgrescluster hippo-ha --overwrite \
  postgres-operator.crunchydata.com/pgbackrest-restore=id1
