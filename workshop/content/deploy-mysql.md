![High-Level Architecture of Tanzu MySQL operator](images/MySQL_ha.png)

{% if ENV_WORKSHOP_TOPIC == 'data-e2e' %}
Let's view our **Petclinic app**. First, we launch it:
```execute
kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-h2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-h2.yaml
```

Check on the status by viewing the logs (**L** on K9s). Click **Esc**  when complete.

Next, we view it:
```dashboard:open-url
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.tanzudatatap.ml
```

Let's go ahead and add a few new pet owners, then restart the app. We notice that if we restart the app, we lose all of our entries:
```execute
kubectl rollout restart deploy/petclinic-app && kubectl rollout status -w deployment/petclinic-app
```

Let's view it again - notice the owners are gone:
```dashboard:reload-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.tanzudatatap.ml
```

To resolve this, we will need to provision a persistent data store.

{% endif  %}

**Tanzu MySQL** is a _full-featured_ object-relational data store.

Let's deploy the Tanzu MySQL **operator**:

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall MySQL --namespace default; helm uninstall MySQL --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep MySQL); do kubectl delete clusterrole ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterrolebinding | grep MySQL); do kubectl delete clusterrolebinding ${i} > /dev/null 2>&1; done; for i in $(kubectl get certificate -n cert-manager | grep MySQL); do kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterissuer | grep MySQL); do kubectl delete clusterissuer ${i} > /dev/null 2>&1; done; for i in $(kubectl get mutatingwebhookconfiguration | grep MySQL); do kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get validatingwebhookconfiguration | grep MySQL); do kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get crd | grep MySQL); do kubectl delete crd ${i} > /dev/null 2>&1; done; helm install MySQL ~/other/resources/MySQL/operator1.6.0 -f ~/other/resources/MySQL/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null; kubectl apply -f ~/other/resources/MySQL/operator1.6.0/crds/
```

The operator deploys a set of **Custom Resource Definitions** which encapsulate various advanced, DB-specific concepts as managed Kubernetes resources. 
The main advantage of the Operator pattern comes from its declarative approach. 
Users can focus on defining domain objects,
while delegating their underlying implementation logic to the operator's controller, which manages their state via reconciliation loops.

Here is a list of the **Custom Resource Definitions** that were deployed by the operator:

```execute
clear && kubectl api-resources --api-group=sql.tanzu.vmware.com
```

Some of these **CRDs** will be useful when declaring a **cluster**; for example, show the list of supported **MySQLversions**:
```execute-2
:MySQLversions
```

Return to the pod view:
```execute-2
:pod
```

Next, let's deploy a highly available Tanzu MySQL **cluster**. Here is the manifest:
```editor:open-file
file: ~/other/resources/MySQL/MySQL-cluster.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/MySQL/MySQL-cluster.yaml -n {{ session_namespace }}
```

This configuration will deploy a MySQL cluster with 1 **primary node**, 1 **mirror node** as a standby node for failover, 
and 1 **monitor node** for tracking the state of the cluster for failover purposes.
View the complete configuration associated with the newly deployed MySQL cluster:
```execute
kubectl get MySQL pginstance-1 -o yaml
```

{% if ENV_WORKSHOP_TOPIC == 'data-e2e' %}
After that, we can redeploy our app:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-MySQL.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:MySQLql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-MySQL.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-MySQL.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-MySQL.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-MySQL.yaml
```

This time, our data persists even after restarting:
```execute
export tmp_db_db=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' | base64 --decode) && export tmp_db_user=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' | base64 --decode) && export tmp_db_pass=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' | base64 --decode) && kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-MySQL-2.yaml && sed -i "s/YOUR_DATASOURCE_URL/jdbc:MySQLql:\/\/pginstance-1:5432\/${tmp_db_db}/g" ~/other/resources/petclinic/petclinic-app-MySQL-2.yaml && sed -i "s/YOUR_DATASOURCE_USERNAME/${tmp_db_user}/g" ~/other/resources/petclinic/petclinic-app-MySQL-2.yaml && sed -i "s/YOUR_DATASOURCE_PASSWORD/${tmp_db_pass}/g" ~/other/resources/petclinic/petclinic-app-MySQL-2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-MySQL-2.yaml
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

Tanzu MySQL uses **pg_auto_fail** for automated failover. 
The **monitor** node tracks the state of the cluster and handles activities such as initiations, promotions/demotions, 
streaming replication (synchronous and asynchronous - synchronous by default).

Let's demonstrate it by killing the primary node by <b>selecting the primary node in the lower console and hitting <font color="red">Ctrl-K</font>.</b>
Observe the activity in the cluster:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pg_autoctl show state'
```

#### Monitoring MySQL Data
![Tanzu MySQL Operator Monitoring](images/MySQL_metrics.png)
Tanzu MySQL includes a **MySQL Exporter** which collects and exposes Prometheus metrics via a _/metrics_ endpoint.

Show a sampling of the emitted metrics:

```execute
clear; kubectl port-forward pginstance-1-0 9187:9187 > /dev/null & TMP_PG_PROC=$!; sleep 2; curl -k https://localhost:9187/metrics
```

Kill the port-forward to proceed:
```execute
kill -9 $TMP_PG_PROC
```

Now that the Prometheus metrics are being exposed, we will be able to deploy a **forwarder** which will scrape the Prometheus endpoints and forward the metrics to the Prometheus aggregator.
The Prometheus operator provides a **PodMonitor** which will handle scraping and forwarding the exposed MySQL metrics.

Set up the **PodMonitor**:
```editor:open-file
file: ~/other/resources/MySQL/MySQL-pod-monitor.yaml
```

Deploy the **PodMonitor**:
```execute
kubectl apply -f ~/other/resources/MySQL/MySQL-pod-monitor.yaml
```

Next, navigate to the Prometheus UI, select Status -> Targets and click "Collapse All" - _podMonitor_ metrics 
should be shown (<font color="red">NOTE:</font> Wait for a few seconds if the metrics do not show up right away):
```dashboard:open-url
name: Prometheus
url: http://prometheus.tanzudatatap.ml
```

<font color="red">NOTE:</font> To view specific metrics collected by Prometheus, go the the Prometheus UI Home screen by 
clicking on "Prometheus" in the menu bar, and enter **pg** in the Search bar. A list of metrics should be populated in the field.

#### Backups and Restores
Tanzu MySQL includes **pgbackrest** as its backup-restore solution for **pgdata** backups, using an S3-compatible store. Here, we will use **Minio** for backup storage.

First, get the Minio login credentials:
```execute
clear &&  mc config host add --insecure data-fileingest-minio https://{{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && printf "Username: $(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)\nPassword: $(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)\n"
```

Let's create a new bucket for our **pgdata** backups:
```execute
mc mb --insecure -p data-fileingest-minio/pg-backups
```

View the newly created bucket (login with the _Username_ and _Password_ printed earlier):
```dashboard:open-url
url: https://minio.tanzudatatap.ml/
```

Next, let's view the manifest that we would use to configure the backup location **pgBackRest**:
```editor:open-file
file: ~/other/resources/MySQL/MySQL-backup-location.yaml
```

Deploy the configuration for the backup location:
```execute
kubectl  apply -f ~/other/resources/MySQL/MySQL-backup-location.yaml  -n {{ session_namespace }}
```

Let's take a look at the backup configuration that was just deployed:
```execute
kubectl get MySQLbackuplocation pg-simple-backuplocation -o jsonpath={.spec} -n {{ session_namespace }} | jq
```

Next, trigger an on-demand backup by deploying a new **MySQLBackup** definition. View the manifest:
```editor:open-file
file: ~/other/resources/MySQL/MySQL-backup.yaml
```

Deploy the backup definition. <font color="red">TODO - wait for the 3 MySQL instance nodes to be restored first.</font>
```execute
kubectl apply -f ~/other/resources/MySQL/MySQL-backup.yaml -n {{ session_namespace }}
```

View the generated backup files on Minio: <font color="red">TODO - working with DB team</font>
```dashboard:open-url
url: https://minio.tanzudatatap.ml/
```

View the backup progress here:
```execute
kubectl get MySQLbackup pg-simple-backup -n {{ session_namespace }}
```

Information about backups can also be gotten directly from the **pgbackrest** cli: <font color="red">TODO</font>
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest info --stanza=${BACKUP_STANZA_NAME}'
```

View other commands provided by **pgBackRest**:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest help'
```

<font color="red">TODO:</font> Restore the last backup.

#### Demonstrating multi cluster deployments
The **Operator pattern** of Tanzu MySQL allows for the deployment of multiple MySQL clusters from a centralized controller.
This greatly simplifies configuration management for each MySQL cluster.

In order to further streamline cluster management, a **GitOps** workflow is preferred. Among other things, the **GitOps** 
approach provides a way to enforce "separation of concerns" between the team that *owns* the database 
and the team that *deploys* it. Database owners can make changes to the database without requiring access to the underlying 
Kubernetes cluster, which simplifies access management and improves repeatability/reliability. 
Also, because **GitOps** is a declarative, "closed loop" approach, 
where git is used as the source of truth for the database clusters, tracking and applying changes is now an automated process, 
rather than being a pipeline-driven process (common with more traditional, imperative pipelines).

To demonstrate the multi-cluster deployment capability of the **Tanzu MySQL** operator using GitOps, we will use **ArgoCD**.

Let's set up ArgoCD:
```execute
git clone https://oawofolu:{{DATA_E2E_GIT_FLUXDEMO_TOKEN}}@gitlab.com/oawofolu/MySQL-repo.git && cd MySQL-repo && git rm app/pginstance2.yaml > /dev/null 2>&1; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git commit -a -m 'New commit' && git push; cd $HOME && kubectl config set-context --current --namespace=argocd && ./argocd app delete MySQL-${session_namespace} -y >/dev/null 2>&1; ./argocd login --core && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/MySQL/MySQL-argocd-app.yaml && kubectl apply -f ~/other/resources/MySQL/MySQL-argocd-app.yaml
```

Next, we will add a manifest representing a new cluster, **pginstance-2**, to our ArgoCD-tracked repository. Copy the content of this file:
```editor:open-file
file: ~/other/resources/MySQL/MySQL-cluster-2.yaml
```

Go to **GitLab**:
```dashboard:open-url
url: https://gitlab.com/oawofolu/MySQL-repo.git
```

Go into the **app** folder, then paste the previously copied content in a new file called **pginstance2.yaml** and commit.
You should see a new ArgoCD application:
```execute
watch ./argocd app get MySQL-{{session_namespace}}
```

Eventually, the pods for the new cluster should start showing up below. Enter **Ctrl-C** to exit the *watch* statement.

Meanwhile, ensure that you are able to access your databases. **pgAdmin** is a popular graphical interface for many database adminstration tasks.
Launch **pgAdmin** here (use "chart@example.local/SuperSecret" as login credentials:)
```dashboard:open-url
url: http://pgadmin.{{ ingress_domain }}
```

Next, create a connection to the database. Click on "Add New Server" and enter the following:
```execute
printf "Under General tab:\n  Server: pginstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: pginstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: pginstance-1\n  Username: pgadmin\n  Password: $(kubectl get secret pginstance-1-db-secret -n {{session_namespace}} -o jsonpath='{.data.password}' | base64 --decode)\n"
```

(When done, select the server "Servers" and click "Remove Server".)


<font color="red"><b>NOTE: Restore default context before proceeding.</b></font>
```execute
kubectl config set-context --current --namespace={{session_namespace}}
```