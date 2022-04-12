![High-Level Architecture of Tanzu MySQL operator - HA](images/MySQL_ha.png)

<font color="red">NOTE:</font> Here is a single-instance version of the Tanzu MySQL architecture (Tanzu MySQL supports both):
![High-Level Architecture of Tanzu MySQL operator - Single Instance](images/MySQL_single.jpeg)

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

**Tanzu MySQL** is a _full-featured_, fast/easy-to-use relational data store.

Let's deploy the Tanzu MySQL **operator**:

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall mysql --namespace default; helm uninstall mysql --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep mysql); do kubectl delete clusterrole ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterrolebinding | grep mysql); do kubectl delete clusterrolebinding ${i} > /dev/null 2>&1; done; for i in $(kubectl get certificate -n cert-manager | grep mysql); do kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterissuer | grep mysql); do kubectl delete clusterissuer ${i} > /dev/null 2>&1; done; for i in $(kubectl get mutatingwebhookconfiguration | grep mysql); do kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get validatingwebhookconfiguration | grep mysql); do kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get crd | grep mysql); do kubectl delete crd ${i} > /dev/null 2>&1; done; helm install mysql ~/other/resources/mysql/operator{{DATA_E2E_MYSQL_OPERATOR_VERSION}} -f ~/other/resources/mysql/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null
```

The operator deploys a set of **Custom Resource Definitions** which encapsulate various advanced, DB-specific concepts as managed Kubernetes resources. 
The main advantage of the Operator pattern comes from its declarative approach. 
Users can focus on defining domain objects,
while delegating their underlying implementation logic to the operator's controller, which manages their state via reconciliation loops.

Here is a list of the **Custom Resource Definitions** that were deployed by the operator:

```execute
clear && kubectl api-resources --api-group=mysql.with.tanzu.vmware.com
```

Some of these **CRDs** will be useful when declaring a **cluster**; for example, show the list of supported **mysqlversions**:
```execute-2
:mysqlversions
```

Return to the pod view:
```execute-2
:pod
```

Next, let's deploy a highly available Tanzu MySQL **cluster**. Here is the manifest:
```editor:open-file
file: ~/other/resources/mysql/mysql-cluster.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/mysql/mysql-cluster.yaml -n {{ session_namespace }}
```

This configuration will deploy a MySQL cluster with 1 **primary node**, 1 **mirror node** as a standby node for failover, 
and 1 **monitor node** for tracking the state of the cluster for failover purposes.
View the complete configuration associated with the newly deployed MySQL cluster:
```execute
kubectl get mysql mysqlinstance-1 -o yaml
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

#### Demonstrating HA

Connect to the new MySQL instance via **phpMyAdmin**, a popular web-based MySQL client.
<font color='red'>NOTE: Wait for all 3 pods to show up in the lower console view before running.</font>
First, set up **phpMyAdmin** to connect to the MySQL instance:
```execute
export MYSQL_ROOT_PASSWORD=$(kubectl exec -it mysqlinstance-1-0 --container=mysql -- cat $MYSQL_ROOT_PASSWORD_FILE) && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/phpMyAdmin/phpMyAdmin.yaml && sed -i "s/YOUR_ROOT_PASSWORD/${MYSQL_ROOT_PASSWORD}/g" ~/other/resources/phpMyAdmin/phpMyAdmin.yaml && kubectl apply -f ~/other/resources/phpMyAdmin/phpMyAdmin.yaml
```

Launch **phpMyAdmin**:
```dashboard:open-url
url: http://phpadmin-{{session_namespace}}.tanzudatatap.ml/
```

Use the credentials emitted below:
```execute
printf "Server: mysqlinstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: mysqlinstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: mysql\n  Username: root\n  Password: ${MYSQL_ROOT_PASSWORD}\n"
```

Once connected, execute the following query:
```copy
echo "SELECT * FROM performance_schema.replication_group_members\G;"
```

Tanzu MySQL uses **InnoDB Cluster** for high availability. In turn, **InnoDB Cluster** uses **Group Replication** for failover and promotions/demotions. 
A highly-available Tanzu MySQL cluster consists of 5 nodes: the **primary/read-write** node which handles query requests,
2 **secondary/read-only/failover** nodes which perform synchronous replication with the primary node, 
and 2 **proxy** nodes which use **MySQL Router** to route requests to the primary node.

Let's demonstrate it by killing the primary node by <b>selecting the primary node in the lower console and hitting <font color="red">Ctrl-K</font>.</b>
Observe the activity in the cluster.

#### Backups and Restores
Tanzu MySQL includes **Percona XtraBackup** as its backup-restore solution for MySQL backups, using an S3-compatible store. Here, we will use **Minio** for backup storage.

First, get the Minio login credentials:
```execute
clear &&  mc config host add --insecure data-fileingest-minio https://{{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && printf "Username: $(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)\nPassword: $(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)\n"
```

Let's create a new bucket for our **mysqldata** backups:
```execute
mc mb --insecure -p data-fileingest-minio/mysql-backups
```

View the newly created bucket (login with the _Username_ and _Password_ printed earlier):
```dashboard:open-url
url: https://minio.tanzudatatap.ml/
```

Next, let's view the manifest that we would use to configure the backup location **pgBackRest**:
```editor:open-file
file: ~/other/resources/mysql/mysql-backup-location.yaml
```

Deploy the configuration for the backup location:
```execute
kubectl  apply -f ~/other/resources/mysql/mysql-backup-location.yaml  -n {{ session_namespace }}
```

Let's take a look at the backup configuration that was just deployed:
```execute
kubectl get MySQLbackuplocation pg-simple-backuplocation -o jsonpath={.spec} -n {{ session_namespace }} | jq
```

Next, trigger an on-demand backup by deploying a new **MySQLBackup** definition. View the manifest:
```editor:open-file
file: ~/other/resources/mysql/mysql-backup.yaml
```

Deploy the backup definition. <font color="red">TODO - wait for the 3 MySQL instance nodes to be restored first.</font>
```execute
kubectl apply -f ~/other/resources/mysql/mysql-backup.yaml -n {{ session_namespace }}
```

View the generated backup files on Minio: <font color="red">TODO - working with DB team</font>
```dashboard:open-url
url: https://minio.tanzudatatap.ml/
```

View the backup progress here:
```execute
kubectl get mysqlbackup pg-simple-backup -n {{ session_namespace }}
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

#### Rotating Credentials
