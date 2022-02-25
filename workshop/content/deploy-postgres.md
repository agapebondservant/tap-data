![Tanzu Data](images/postgres_ha.png)

{% if ENV_WORKSHOP_TOPIC == 'data-e2e' %}
Let's view our **Petclinic app**. First, we launch it:
```execute
kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-h2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-h2.yaml
```

Check on the status by viewing the logs (**L** on K9s). Click **Esc**  when complete.

Next, we view it:
```dashboard:create-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.mytanzu.ml
```

Let's go ahead and add a few new pet owners, then restart the app. We notice that if we restart the app, we lose all of our entries:
```execute
kubectl rollout restart deploy/petclinic-app && kubectl rollout status -w deployment/petclinic-app
```

Let's view it again - notice the owners are gone:
```dashboard:reload-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.mytanzu.ml
```

To resolve this, we will need to provision a persistent data store.

{% endif  %}

**Tanzu Postgres** is a _full-featured_ object-relational data store.

Let's deploy the Tanzu Postgres **operator**:

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm uninstall postgres --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep postgres); do kubectl delete clusterrole ${i}; done; for i in $(kubectl get clusterrolebinding | grep postgres); do kubectl delete clusterrolebinding ${i}; done; for i in $(kubectl get certificate -n cert-manager | grep postgres); do kubectl delete certificate -n cert-manager ${i}; done; for i in $(kubectl get clusterissuer | grep postgres); do kubectl delete clusterissuer ${i}; done; for i in $(kubectl get mutatingwebhookconfiguration | grep postgres); do kubectl delete mutatingwebhookconfiguration ${i}; done; for i in $(kubectl get validatingwebhookconfiguration | grep postgres); do kubectl delete validatingwebhookconfiguration ${i}; done; for i in $(kubectl get crd | grep postgres); do kubectl delete crd ${i}; done; helm install postgres ~/other/resources/postgres/operator1.5.0 -f ~/other/resources/postgres/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null; kubectl apply -f ~/other/resources/postgres/operator1.5.0/crds/
```

The operator deploys a set of **Custom Resource Definitions** which encapsulate various advanced, DB-specific concepts as managed Kubernetes resources. 
The main advantage of the Operator pattern comes from its declarative approach. 
Users can focus on defining domain objects,
while delegating their underlying implementation logic to the operator's controller, which manages their state via reconciliation loops.

Here is a list of the **Custom Resource Definitions** that were deployed by the operator:

```execute
clear && kubectl api-resources --api-group=sql.tanzu.vmware.com
```

Some of these **CRDs** will be useful when declaring a **cluster**; for example, show the list of supported **postgresversions**:
```execute-2
:postgresversions
```

Return to the pod view:
```execute-2
:pod
```

Next, let's deploy a highly available Tanzu Postgres **cluster**. Here is the manifest:
```editor:open-file
file: ~/other/resources/postgres/postgres-cluster.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster.yaml -n {{ session_namespace }}
```

This configuration will deploy a Postgres cluster with 1 **primary node**, 1 **mirror node** as a standby node for failover, 
and 1 **monitor node** for tracking the state of the cluster for failover purposes.
View the complete configuration associated with the newly deployed Postgres cluster:
```execute
kubectl get postgres pginstance-1 -o yaml
```

{% if ENV_WORKSHOP_TOPIC == 'data-e2e' %}
After that, we can redeploy our app:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:postgresql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-postgres.yaml
```

This time, our data persists even after restarting:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:postgresql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-postgres-2.yaml
```

{% endif  %}

{% if ENV_WORKSHOP_TOPIC == 'data-file-ingestion' %}
#### Create a database table

On the lower console, select the **primary** pod, launch the shell by typing **s**, then launch the **psql** console by executing the following:
```execute-2
psql -d pginstance-1
```

Create a new table, **test**, with a **JSONB** column:
```execute-2
create table test (id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, ingest_time timestamp DEFAULT CURRENT_TIMESTAMP, data jsonb NOT NULL);
```

Query the new table:
```execute-2
select * from test;
```

Exit the **psql** console.
```execute-2
\q
```

Return  to the pod view.
```execute-2
exit
```

{% endif  %}

#### Demonstrating HA

Show the primary node: <font color='red'>NOTE: Wait for all 3 pods to show up in the lower console view before running.</font>
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pg_autoctl show state'
```

Tanzu Postgres uses **pg_auto_fail** for automated failover. 
The **monitor** node tracks the state of the cluster and handles activities such as initiations, promotions/demotions, 
streaming replication (synchronous and asynchronous - synchronous by default).

Let's demonstrate it by killing the primary node by <b>selecting the primary node in the lower console and hitting <font color="red">Ctrl-K</font>.</b>
Observe the activity in the cluster:
```execute
watch kubectl exec -it pginstance-1-1 -- bash -c 'pg_autoctl show state'
```

After the promotion/demotion activity has completed (the new primary has been promoted and the other replica has been demoted to a mirror node), exit the loop.
```terminal:interrupt
session: 1
```

#### Demonstrating multi cluster deployments

#### Monitoring Postgres Data
Tanzu Postgres includes a **Postgres Exporter** which collects and exposes Prometheus metrics via a _/metrics_ endpoint.

Show a sampling of the emitted metrics:

```execute
clear; kubectl port-forward pginstance-1-0 9187:9187 > /dev/null & TMP_PG_PROC=$!; sleep 2; curl -k https://localhost:9187/metrics
```

Kill the port-forward to proceed:
```execute
kill -9 $TMP_PG_PROC
```

#### Backups and Restores
Tanzu Postgres includes **pgbackrest** as its backup-restore solution for **pgdata** backups, using an S3-compatible store. Here, we will use **Minio** for backup storage.

First, get the Minio login credentials:
```execute
clear &&  mc config host add --insecure data-fileingest-minio https://{{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && printf "Username: $(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)\nPassword: $(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)\n"
```

Let's create  a new bucket for our **pgdata** backups:
```execute
mc mb --insecure -p data-fileingest-minio/pgbackups
```

View the newly created bucket (login with the _Username_ and _Password_ printed earlier):
```dashboard:open-url
url: https://minio.mytanzu.ml/
```

Next, let's view the manifest that we would use to enable **pgBackRest**:
```editor:open-file
file: ~/other/resources/postgres/postgres-cluster-with-backups.yaml
text: "apiVersion"
before: 0
after: 13
```

Update the Postgres cluster to enable **pgBackRest**:
```execute
kubectl  replace --force -f ~/other/resources/postgres/postgres-cluster-with-backups.yaml  -n {{ session_namespace }}
```

Set up the **pgbackrest** configuration in the primary node: 
```execute
export $(kubectl exec -ti pginstance-1-1 -- bash -c "env | grep BACKUP_STANZA_NAME")
```

Create a backup  using **pgBackRest**.
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest stanza-create --stanza=$BACKUP_STANZA_NAME && pgbackrest backup --stanza=${BACKUP_STANZA_NAME}'
```

View the generated backup files on Minio:
View the newly created bucket:
```dashboard:open-url
url: https://minio.mytanzu.ml/
```

Get information about the last backup:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest info --stanza=${BACKUP_STANZA_NAME}'
```

View other commands provided by **pgBackRest**:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest help'
```

<font color="red">TODO:</font> Restore the last backup.
