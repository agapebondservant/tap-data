
### Deploying Tanzu Postgres

{% if WORKSHOP_TOPIC == 'data-e2e' %}
Let's view our **Petclinic app**. First, we launch it:
```execute
kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-h2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-h2.yaml
```

Check on the status by viewing the logs (**L** on K9s). Click **Esc**  when complete.

Next, we view it:
```dashboard:create-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.tanzudata.ml
```

Let's go ahead and add a few new pet owners, then restart the app. We notice that if we restart the app, we lose all of our entries:
```execute
kubectl rollout restart deploy/petclinic-app && kubectl rollout status -w deployment/petclinic-app
```

Let's view it again - notice the owners are gone:
```dashboard:reload-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.tanzudata.ml
```

To resolve this, we will need to provision a persistent data store.

{% endif  %}

**Tanzu Postgres** is a _full-featured_ object-relational data store.

Let's deploy the Tanzu Postgres **operator**:

<font color="red">NOTE: Do NOT run this if your workshop instance is not the first generated one, i.e. only run for workshop sessions ending in '001'.</font>

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm install postgres ~/other/resources/postgres/operator -f ~/other/resources/postgres/overrides.yaml --set tmpNamespace=default
```

Next, let's deploy a highly available Tanzu Postgres **cluster**. Here is the manifest:
```editor:open-file
file: ~/other/resources/postgres/postgres-cluster.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster.yaml -n {{ session_namespace }}
```

Show the primary node: <font color='red'>NOTE: Wait for all 3 Postgres cluster nodes (pods) to show up in the lower console view before running.</font>
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pg_autoctl show state'
```

{% if WORKSHOP_TOPIC == 'data-e2e' %}
After that, we can redeploy our app:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:postgresql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-postgres.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-postgres.yaml
```

This time, our data persists even after restarting:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:postgresql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-postgres-2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-postgres-2.yaml
```

{% endif  %}

{% if WORKSHOP_TOPIC == 'data-file-ingestion' %}
#### Create a database table

On the lower console, select the **primary** pod, launch the shell by typing **s**, then launch the **psql** console by executing the following:
```execute-2
psql
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

#### Backups and Restores
Tanzu Postgres includes **pgbackrest** as its backup-restore solution for **pgdata** backups, using an S3-compatible store. Here, we will use **Minio** for backup storage.


First, get the Minio login credentials:
```execute
clear &&  mc config host add data-fileingest-minio http://{{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && printf "Username: $(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)\nPassword: $(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)\n"
```

Let's create  a new bucket for our **pgdata** backups:
```execute
mc mb -p data-fileingest-minio/pgbackups
```

View the newly created bucket:
```dashboard:open-url
url: http://minio.tanzudata.ml/
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

Set up the **pgbackrest** configuration in the primary node: <font color='red'>NOTE: For Minio buckets, ill not work unless the Minio server has enabled TLS.</font>
```execute
export $(kubectl exec -ti pginstance-1-1 -- bash -c "env | grep BACKUP_STANZA_NAME")
```

<font color="red">TODO:</font> Create a backup  using **pgBackRest**.
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest check --stanza=${BACKUP_STANZA_NAME} && pgbackrest stanza-create --stanza=$BACKUP_STANZA_NAME && pgbackrest backup --stanza=${BACKUP_STANZA_NAME}'
```
