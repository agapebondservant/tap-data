![High-Level Architecture of Tanzu Postgres operator](images/postgres_ha.png)

{% if ENV_WORKSHOP_TOPIC == 'data-e2e' %}
Let's view our **Petclinic app**. First, we launch it:
```execute
kubectl delete deployment petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=true --namespace={{ session_namespace }} && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic/petclinic-app-h2.yaml && kubectl apply -f ~/other/resources/petclinic/petclinic-app-h2.yaml
```

Check on the status by viewing the logs (**L** on K9s). Click **Esc**  when complete.

Next, we view it:
```dashboard:open-url
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.{{ DATA_E2E_BASE_URL }}
```

Let's go ahead and add a few new pet owners, then restart the app. We notice that if we restart the app, we lose all of our entries:
```execute
kubectl rollout restart deploy/petclinic-app && kubectl rollout status -w deployment/petclinic-app
```

Let's view it again - notice the owners are gone:
```dashboard:reload-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-{{ session_namespace }}.{{ DATA_E2E_BASE_URL }}
```

To resolve this, we will need to provision a persistent data store.

{% endif  %}

**Tanzu Postgres** is a _full-featured_ object-relational data store.

{% if ENV_WORKSHOP_TOPIC != 'data-with-tap' and ENV_WORKSHOP_TOPIC != 'data-with-tap-demo' %}
Let's deploy the Tanzu Postgres **operator**:

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm uninstall postgres --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep postgres | grep -v postgres-operator-default-cluster-role); do kubectl delete clusterrole ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterrolebinding | grep postgres | grep -v postgres-operator-default-cluster-role-binding); do kubectl delete clusterrolebinding ${i} > /dev/null 2>&1; done; for i in $(kubectl get certificate -n cert-manager | grep postgres); do kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterissuer | grep postgres); do kubectl delete clusterissuer ${i} > /dev/null 2>&1; done; for i in $(kubectl get mutatingwebhookconfiguration | grep postgres); do kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get validatingwebhookconfiguration | grep postgres); do kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get crd | grep postgres); do kubectl delete crd ${i} > /dev/null 2>&1; done; helm install postgres ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}} -f ~/other/resources/postgres/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null; kubectl apply -f ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}}/crds/ 
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

Clusters can also be deployed by using the **Tanzu Operator UI**. First, refresh the UI settings to ensure that it is in sync with the latest Operator changes:
```execute
~/other/resources/operator-ui/annotate.sh
```

Now access the Operator UI:
```dashboard:open-url
url: http://operator-ui.{{ ingress_domain }}
```

{% endif %}

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

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap' or ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
First, let's add some data to our system. Navigate to the Petclinic app deployed earlier and add some pet related info:
```dashboard:open-url
url: http://pet-clinic.{{ session_namespace }}.{{ ingress_domain }}
```
{% endif %}

Let's demonstrate HA by killing the primary node by <b>selecting the primary node in the lower console and hitting <font color="red">Ctrl-K</font>.</b>
Observe the activity in the cluster:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pg_autoctl show state'
```

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap' or ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
Confirm that the data added has not been lost:
```dashboard:open-url
url: http://pet-clinic.{{ session_namespace }}.{{ ingress_domain }}
```
{% endif %}

**Tanzu Postgres** automatically configures a proxy service for routing to the appropriate (primary) node:
```execute
kubectl get svc pginstance-1 -oyaml --namespace {{ session_namespace }}
```

#### Monitoring Postgres Data
![Tanzu Postgres Operator Monitoring](images/postgres_metrics.png)
Tanzu Postgres includes a **Postgres Exporter** which collects and exposes Prometheus metrics via a _/metrics_ endpoint.

Show a sampling of the emitted metrics:

```execute
clear; kubectl port-forward pginstance-1-0 9187:9187 > /dev/null & TMP_PG_PROC=$!; sleep 2; curl -k https://localhost:9187/metrics
```

Kill the port-forward to proceed:
```execute
kill -9 $TMP_PG_PROC
```

Now that the Prometheus metrics are being exposed, we will be able to deploy a **forwarder** which will scrape the Prometheus endpoints and forward the metrics to the Prometheus aggregator.
The Prometheus operator provides a **PodMonitor** which will handle scraping and forwarding the exposed Postgres metrics.

Set up the **PodMonitor**:
```editor:open-file
file: ~/other/resources/postgres/postgres-pod-monitor.yaml
```

Deploy the **PodMonitor**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-pod-monitor.yaml
```

Next, navigate to the Prometheus UI, select Status -> Targets and click "Collapse All" - _podMonitor_ metrics 
should be shown (<font color="red">NOTE:</font> Wait for a few seconds if the metrics do not show up right away):
```dashboard:open-url
name: Prometheus
url: http://prometheus.{{ DATA_E2E_BASE_URL }}
```

<font color="red">NOTE:</font> The endpoints should match the pod IPs shown here:
```execute
kubectl get pods -o wide
```


<font color="red">NOTE:</font> To view specific metrics collected by Prometheus, go the the Prometheus UI Home screen by 
clicking on "Prometheus" in the menu bar, and enter **pg** in the Search bar. A list of metrics should be populated in the field.

Also, **Tanzu Postgres** supports out-of-the-box integration with **Wavefront** (Tanzu Observability). On **Kubernetes**, 
this is enabled via the **Wavefront Collector**, which is an agent that runs on each node to collect and forward metrics to Wavefront. 
By simply installing the **Wavefront Collector** in our Kubernetes cluster, we should be able to access to a set of pre-defined metrics, 
dashboards and alerts for **Tanzu Postgres**.

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
Deploy the **Wavefront Collector** which will handle collecting and forwarding metrics to Wavefront:
```execute
helm repo add wavefront https://wavefronthq.github.io/helm/ && kubectl create namespace wavefront --dry-run -o yaml | kubectl apply -f - ; (helm uninstall wavefront -n wavefront ; helm install wavefront wavefront/wavefront --set wavefront.url=https://vmware.wavefront.com --set wavefront.token={{ DATA_E2E_WAVEFRONT_ACCESS_TOKEN }} --set clusterName=tanzu-data-samples-cluster --set collector.discovery.annotationPrefix=wavefront.com -n wavefront)
```
{% endif %}

View the Wavefront dashboard here (select **tanzu-data-samples-cluster**):
```dashboard:open-url
name: Wavefront
url: https://vmware.wavefront.com/u/9cBZt51YkS?t=vmware
```

#### Backups and Restores
Tanzu Postgres includes **pgbackrest** as its backup-restore solution for **pgdata** backups, using an S3-compatible store. Here, we will use **Minio** for backup storage.

First, get the Minio login credentials:
```execute
clear &&  mc config host add --insecure data-fileingest-minio https://{{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && printf "Username: $(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)\nPassword: $(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)\n"
```

Let's create a new bucket for our **pgdata** backups:
```execute
mc rb --force --insecure data-fileingest-minio/pg-backups; mc mb --insecure -p data-fileingest-minio/pg-backups
```

View the newly created bucket (login with the _Username_ and _Password_ printed earlier):
```dashboard:open-url
url: https://minio.{{ DATA_E2E_BASE_URL }}/
```

Next, let's view the manifest that we would use to configure the backup location **pgBackRest** <font color="red">If desired, update the **bucketPath** to any unique location of your choosing.</font>:
```editor:open-file
file: ~/other/resources/postgres/postgres-backup-location.yaml
```

**PostgresBackupLocations** support the ability to configure both full and differential **retention** policies:
```editor:append-lines-after-match
file: ~/other/resources/postgres/postgres-backup-location.yaml
match: Can configure retention policy
text: |
      #retentionPolicy:
        #fullRetention:
          #type: count
          #number: 9999999
        #diffRetention:
          #number: 9999999
```

Deploy the configuration for the backup location:
```execute
kubectl  apply -f ~/other/resources/postgres/postgres-backup-location.yaml  -n {{ session_namespace }}
```

Let's take a look at the backup configuration that was just deployed:
```execute
kubectl get postgresbackuplocation pg-simple-backuplocation -o jsonpath={.spec} -n {{ session_namespace }} | jq
```

Next, trigger an on-demand backup by deploying a new **PostgresBackup** definition. View the manifest:
```editor:open-file
file: ~/other/resources/postgres/postgres-backup.yaml
```

Deploy the backup definition. <font color="red">TODO - wait for the 3 Postgres instance nodes to be restored first.</font>
```execute
kubectl apply -f ~/other/resources/postgres/postgres-backup.yaml -n {{ session_namespace }}
```

View the generated backup files on Minio:
```dashboard:open-url
url: https://minio.{{ DATA_E2E_BASE_URL }}/
```

View the backup progress here: <font color="red">NOTE: Hit **Ctrl-C** to exit.</font>
```execute
watch kubectl get postgresbackup pg-simple-backup -n {{ session_namespace }}
```

Information about backups can also be gotten directly from the **pgbackrest** cli:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest info --stanza=${BACKUP_STANZA_NAME}'
```

View other commands provided by **pgBackRest**:
```execute
kubectl exec -it pginstance-1-1 -- bash -c 'pgbackrest help'
```

Next, let's perform a restore. We create a new target namespace to restore to:
```execute
kubectl delete ns pg-restore-{{ session_namespace }} || true; kubectl create ns pg-restore-{{ session_namespace }}
```

Switch to the new namespace in the lower console:
```execute-2
:namespace
```

View the manifest to be applied to the new namespace to restore `pg-simple-backup`:
```editor:open-file
file: ~/other/resources/postgres/postgres-backup-location.yaml
```

Apply the **PostgresBackupLocation** and associated **Secret** to the new namespace, so that existing backups will be synced with the new namespace:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-backup-location.yaml -n pg-restore-{{ session_namespace }}
```

View the synchronized backups: <font color="red">NOTE: Once the status shows "Succeeded", hit **Ctrl-C** to exit.</font>
```execute
watch kubectl get postgresbackup -n pg-restore-{{ session_namespace }} -l sql.tanzu.vmware.com/recovered-from-backuplocation=true 
```

Apply the manifest which will be used to configure the restore. First, update the manifest with the name of the synchronized backup from above:
```execute
export PG_SYNC_RESTORE_NM=$(kubectl get postgresbackup -n pg-restore-{{ session_namespace }} -l sql.tanzu.vmware.com/recovered-from-backuplocation=true -o jsonpath="{.items[0].metadata.name}") && sed -i "s/pg-simple-backup/$PG_SYNC_RESTORE_NM/g" ~/other/resources/postgres/postgres-restore.yaml
```

View the manifest:
```editor:open-file
file: ~/other/resources/postgres/postgres-restore.yaml
```

Apply the restore: <font color="red">NOTE: Wait until the new **pginstance-1** database instance is shown as Running in the lower console.</font>
```execute
kubectl apply -f ~/other/resources/postgres/postgres-restore.yaml -n pg-restore-{{ session_namespace }}
```

Validate the status of the restore: <font color="red">NOTE: Once the Restore is validated as Succeeded, hit **Ctrl-C** to exit:</font>
```execute
watch kubectl get postgresrestore.sql.tanzu.vmware.com/pg-simple-restore -n pg-restore-{{ session_namespace }}
```

<font color="red">NOTE:</font> Switch back to the original namespace:
```execute-2
2
```

#### Demonstrating multi cluster deployments
The **Operator pattern** of Tanzu Postgres allows for the deployment of multiple Postgres clusters from a centralized controller.
This greatly simplifies configuration management for each Postgres cluster.

In order to further streamline cluster management, a **GitOps** workflow is preferred. Among other things, the **GitOps** 
approach provides a way to enforce "separation of concerns" between the team that *owns* the database 
and the team that *deploys* it. Database owners can make changes to the database without requiring access to the underlying 
Kubernetes cluster, which simplifies access management and improves repeatability/reliability. 
Also, because **GitOps** is a declarative, "closed loop" approach, 
where git is used as the source of truth for the database clusters, tracking and applying changes is now an automated process, 
rather than being a pipeline-driven process (common with more traditional, imperative pipelines).

To demonstrate the multi-cluster deployment capability of the **Tanzu Postgres** operator using GitOps, we will use **ArgoCD**.

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
Let's set up ArgoCD:
```execute
git clone https://oawofolu:{{DATA_E2E_GIT_FLUXDEMO_TOKEN}}@gitlab.com/oawofolu/postgres-repo.git && cd postgres-repo && git rm app/pginstance2.yaml > /dev/null 2>&1; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git commit -a -m 'New commit' && git push; cd $HOME; kubectl delete ns argocd || true; kubectl create ns argocd; kubectl apply -f ~/other/resources/argocd/argocd.yaml -n argocd;
```
{% endif %}

Set up an ArgoCD project:
```execute
cd $HOME; kubectl config set-context --current --namespace=argocd && ./argocd app delete postgres-${session_namespace} -y >/dev/null 2>&1; ./argocd login --core && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/postgres/postgres-argocd-app.yaml && kubectl apply -f ~/other/resources/postgres/postgres-argocd-app.yaml && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/postgres/postgres-cluster-2.yaml
```

Next, we will add a manifest representing a new cluster, **pginstance-2**, to our ArgoCD-tracked repository. Copy the content of this file:
```editor:open-file
file: ~/other/resources/postgres/postgres-cluster-2.yaml
```

Go to **GitLab**:
```dashboard:open-url
url: https://gitlab.com/oawofolu/postgres-repo.git
```

Go into the **app** folder, then paste the previously copied content in a new file with the name shown below. Click to copy the file name:
```copy
pginstance2-{{session_namespace}}.yaml
```

Copy-paste the content and commit. You should see a new ArgoCD application:
```execute
watch ./argocd app get postgres-{{session_namespace}}
```

Eventually, the pods for the new cluster should start showing up in the lower console. Enter **Ctrl-C** to exit the *watch* statement.

#### Connecting to the Database
Meanwhile, ensure that you are able to access your databases. **pgAdmin** is a popular graphical interface for many database adminstration tasks.
Launch **pgAdmin** here (use "chart@example.local/SuperSecret" as login credentials:)
```dashboard:open-url
url: http://pgadmin.{{ ingress_domain }}
```

Next, create a connection to the database. Click on "Add New Server" and enter the following:
```execute
printf "Under General tab:\n  Server: pginstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: pginstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: pginstance-1\n  Username: pgadmin\n  Password: $(kubectl get secret pginstance-1-db-secret -n {{session_namespace}} -o jsonpath='{.data.password}' | base64 --decode)\n"
```

Try executing a query in the Query Console (under Tools -> Query Tool) - copy the query below:
```copy
SELECT * FROM pg_settings where name='max_connections';
```

(When done, select the server "Servers" and click "Remove Server".)

##### SecretExport and SecretImport
Sometimes, a connection needs to be made to a database located in a different namespace, or even a different cluster.
Traditionally, this would be handled by manually copying secrets to all the namespaces that need it, which can be a cumbersome process at scale.
For this, we will use Carvel's **SecretGen** component. 

Let's demonstrate it by installing **pgAdmin** in a new namespace.

<font color="red"><b>NOTE: Restore default context before proceeding:</b></font>
```execute
kubectl config set-context --current --namespace={{session_namespace}}
```

Deploy a new instance of pgAdmin using the manifest below:
```execute
helm repo add runix https://helm.runix.net/; helm repo update; helm uninstall pgadmin runix/pgadmin4 --namespace pgadmin-{{ session_namespace }} || true; kubectl delete ns pgadmin-{{ session_namespace }} || true; kubectl create ns pgadmin-{{ session_namespace }}; helm install pgadmin runix/pgadmin4 --set persistence.storageClass=generic --set strategy.type=Recreate --namespace pgadmin-{{ session_namespace }};export PGADMIN_NS_POD_NAME=$(kubectl get pods --namespace pgadmin-{{ session_namespace }} -l "app.kubernetes.io/name=pgadmin4,app.kubernetes.io/instance=pgadmin" -o jsonpath="{.items[0].metadata.name}"); kubectl expose pod $PGADMIN_NS_POD_NAME --name pgadmin-{{ session_namespace }} --port 80 --namespace pgadmin-{{ session_namespace }}
```

Ensure the new deployment was successful: <font color='red'>Click Ctrl^C when the deployment is ready.</font>
```execute
watch kubectl get all  --namespace pgadmin-{{ session_namespace }}
```

Confirm that the secret for the pginstance-1 cluster cannot be accessed from the new namespace:
```execute
kubectl get secret --namespace pgadmin-{{ session_namespace }}
```

The secret needs to be imported from the source. We will use Carvel's **SecretExport** to export the secret from the upstream namespace,
and **SecretImport** to import it into our new namespace. View the manifest:
```editor:open-file
file: ~/other/resources/postgres/pgadmin-secretimportexport.yaml
```

Let's deploy the **SecretExport** and **SecretImport**:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/postgres/pgadmin-secretimportexport.yaml;kubectl apply -f ~/other/resources/postgres/pgadmin-secretimportexport.yaml
```

The secret should now be available:
```execute
kubectl get secret --namespace pgadmin-{{ session_namespace }}
```

##### Service Bindings
For many kinds of users (ex. developers), it would be ideal to provide connectivity to the database 
by having the credentials delivered to them, instead of having to locate the credentials themselves.
The same thing applies to the applications which consume the credentials. 
There should be separation of code and config, meaning that credentials should be
<b>transparently injected into the app by the provider</b>, and the code should be able to consume credentials in a provider-agnostic way.

**Tanzu Postgres** supports **Service Bindings**, which provide a provider-agnostic, standardized approach for setting up connectivity 
between services and applications. 

View the manifest that will be used to configure the Service Binding from our new pgAdmin instance to the pginstance-1 DB instance:
```editor:open-file
file: ~/other/resources/postgres/pgadmin-sb.yaml
```

Deploy the ServiceBinding:
```execute
kubectl apply -f ~/other/resources/postgres/pgadmin-sb-rbac.yaml --namespace pgadmin-{{ session_namespace }}; kubectl apply -f ~/other/resources/postgres/pgadmin-sb.yaml --namespace pgadmin-{{ session_namespace }}
```

The **Service Binding** specification works by volume mounting the secrets delivered by the **Provisioned Service** resource(s)
into the Workload's pod container(s). The secrets are mounted at a dynamically named directory. An environment variable,
called SERVICE_BINDING_ROOT, points to the root of the mount directory.

Start a shell session in the workload's container:
```execute
clear && kubectl exec deploy/pgadmin-pgadmin4 -it -npgadmin-{{ session_namespace }} -- sh
```

Next, view the Service Binding directory's content:
```execute
echo "Service Bindng Mount Path: $SERVICE_BINDING_ROOT"; ls -ltr $SERVICE_BINDING_ROOT/pginstance-1
```

View specific entries - for example, **type** and **provider** are required by the spec, **username** is optional:
```execute
echo Type: $(cat $SERVICE_BINDING_ROOT/pginstance-1/type); echo Provider: $(cat $SERVICE_BINDING_ROOT/pginstance-1/provider); echo Username: $(cat $SERVICE_BINDING_ROOT/pginstance-1/username); exit
```


