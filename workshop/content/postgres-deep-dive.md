![High-Level Architecture of Tanzu Postgres operator](images/postgres_ha.png)
{% if ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
#### Installing Postgres via the Tanzu cli
The primary approach for installing the **Tanzu Postgres** operator is by using **Helm**. However, **TAP** customers have the benefit of 
installing **Tanzu Postgres** using the **Tanzu cli**. In addition to the standard **Helm** packaging, **Tanzu Postgres** provides 
packaging for the operator that uses **Carvel's** **imgpkg** format, which is deployed via **Carvel's** **kapp-controller**.
This approach allows TAP operators to use the same unified toolchain for managing **Tanzu Postgres** that is used for other TAP packages.

First, confirm that the **Tanzu Data Services** package is available in the target registry that will be used for the install:
```execute
echo {{ DATA_E2E_REGISTRY_PASSWORD }} | docker login registry-1.docker.io --username={{ DATA_E2E_REGISTRY_USERNAME }} --password-stdin; if docker manifest inspect {{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} > /dev/null ; then echo "{{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} was found"; else echo "{{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} was not found"; fi
```

Next, export the registry secret that will be used to access the target registry:
```execute
cd ~ && tanzu init && tanzu plugin install --local bin/cli secret && tanzu secret registry delete regsecret --namespace default -y || true; tanzu secret registry add regsecret --username {{ DATA_E2E_REGISTRY_USERNAME }} --password {{ DATA_E2E_REGISTRY_PASSWORD }} --server {{ DATA_E2E_REGISTRY_USERNAME }} --export-to-all-namespaces --yes --namespace default
```

Verify that there is now an exported secret for the target registry:
```execute
tanzu secret registry list --namespace default
```

With that, now we can add the **Package Repository** for **Tanzu Postgres** to our TAP install:
```execute
tanzu package repository add tanzu-postgres-repository --url {{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} --namespace default
```

Verify that the new package repository was added:
```execute
tanzu package available list --namespace default
```

View the `values-schema` which enumerates the operator's default properties: 
```execute
export PG_TANZU_PKG_VERSION=$(tanzu package available list -o json --namespace default | jq '.[] | select(.name=="postgres-operator.sql.tanzu.vmware.com")["latest-version"]' | tr -d '"'); tanzu package available get postgres-operator.sql.tanzu.vmware.com/$PG_TANZU_PKG_VERSION --values-schema --namespace default
```

The operator's default properties may be overidden using a `values.yaml` manifest file 
(<font color="red">NOTE: The value of the Docker registry secret, **dockerRegistrySecretName**, is the secret that was exported earlier</font>):
```editor:select-matching-text
file: ~/other/resources/postgres/postgres-values.yaml
text: "dockerRegistrySecretName"
```

Delete any old instances of the operator:
```execute
tanzu package installed delete postgres-operator -ndefault -y
```

Now install the operator:
```execute
tanzu package install postgres-operator --package-name postgres-operator.sql.tanzu.vmware.com --version $PG_TANZU_PKG_VERSION -f ~/other/resources/postgres/postgres-values.yaml --namespace default
```
{% endif %}

View the logs associated with the operator to confirm its successful deployment:
```execute
kubectl logs -l app=postgres-operator --namespace default
```

The operator deploys a set of **Custom Resource Definitions** which encapsulate various advanced, DB-specific concepts as managed Kubernetes resources.
The main advantage of the Operator pattern comes from its declarative approach.
Users can focus on defining domain objects,
while delegating their underlying implementation logic to the operator's controller, which manages their state via reconciliation loops.

Here is a list of the **Custom Resource Definitions** that were deployed by the operator: <font color="red">NOTE: Wait until the **postgres-operator** pod shows up in the lower console:</font>
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

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap' or ENV_WORKSHOP_TOPIC == 'data-with-tap-demo' %}
#### Deploying a Postgres cluster

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
~/other/resources/operator-ui/annotate.sh; kubectl annotate pkgi postgres-operator ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=postgres-operator-tsqlui-annotation-overlay-secret -ndefault --overwrite
```

Now access the Operator UI:
```dashboard:open-url
url: http://operator-ui.{{ ingress_domain }}
```

##### Service Discovery via Service Offering
**Services Toolkit** includes the notion of a **Service Resource**.
A **Service Resource** represents any software component that integrates with **Workloads**. Technically,
there are no restrictions on what a **Service Resource** can represent; it can literally be anything,
from a database to a DNS record to a message broker to an API credential. However, a **Service Resource** must conform to
the specification defined by the **Service Binding for Kubernetes** standard, which is that it must expose a Kubernetes-based API
resource that conforms to the **Provisioned Service** duck type, **status.binding.name**.

Confirm that the **Postgres** CR includes **status.binding.name** in its schema:
```execute
kubectl explain postgres.status.binding.name
```

**Service Resources** must be advertised by Service Operators so that they can be discovered. With **Services Toolkit**, this is done using the concept
of a **Service Offering**, which uses **Cluster Resource* CRs to define the metadata that describes the **Service Resource** and its topology.

Here is a **Cluster Resource** that can be used to advertise Postgres resources:
```editor:open-file
file: ~/other/resources/postgres/postgres-cluster-resource.yaml
```

Deploy the **Cluster Resource**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster-resource.yaml
```

Now, confirm that the Postgres Service can be discovered using the **tanzu** cli via the Services plug-in: <font color="red">NOTE: Should show the Postgres resource.</font>
```execute
cd ~ && tanzu plugin install --local bin/cli services && tanzu services types list
```

Also confirm that the previously deployed Postgres instance is discoverable via the Services plug-in: 
<font color="red">NOTE: Wait for all 3 Postgres cluster pods to show up in the lower console. Should show the **pginstance-1** Postgres instance.</font>
```execute
tanzu services instances list
```

#### Integrating Workloads with Service Bindings
For **TAP** users, the Tanzu Postgres controller makes it easy to take advantage of Kubernetes' **Service Bindings** for seamlessly binding applications
(called **Workloads**) to database instances (called **Service Resources**).

View the manifest for the integration here:
```editor:select-matching-text
file: ~/other/resources/postgres/postgres-tap.yaml
text: "serviceClaims"
after: 5
```

Notice the highlighted section which defines the **Service Binding**. A **Service Binding** is a Kubernetes standard for sharing 
a **Service**'s connectivity information with a **Workload**. In **Services Toolkit**, it is also represented as a Custom Resource 
which conforms to the **Provisioned Service** spec, meaning that it references a **Secret** in its **status.binding.name** field**.

Create the **Workload** by applying the manifest to the cluster:
```execute
clear && cd ~ && kubectl annotate ns {{session_namespace}} secretgen.carvel.dev/excluded-from-wildcard-matching- && kubectl apply -f ~/other/resources/tap/rbac.yaml && tanzu init && tanzu plugin install --local bin/cli apps && tanzu plugin install --local bin/cli services && tanzu secret registry add regsecret --username {{DATA_E2E_REGISTRY_USERNAME}} --password {{DATA_E2E_REGISTRY_PASSWORD}} --server https://index.docker.io/v1/ --export-to-all-namespaces --yes -n {{session_namespace}} && tanzu secret registry add tap-registry --username {{DATA_E2E_REGISTRY_USERNAME}} --password {{DATA_E2E_REGISTRY_PASSWORD}} --server https://index.docker.io/v1/ --export-to-all-namespaces --yes -n {{session_namespace}} && kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-credentials"},{"name": "tap-registry"}],"secrets":[{"name": "tap-registry"}]}' && kubectl apply -f ~/other/resources/postgres/postgres-tap.yaml
```

Tail the logs of the newly deployed **Workload**. 
<font color="red">NOTE: It may take a few seconds for the logs to show up. Hit **Ctrl-C** to exit once the deployment completes</font>:
```execute
tanzu apps workload tail pet-clinic --since 64h
```

View the app details. <font color="red">NOTE: Wait until at least one **pet-clinic** pod shows up as Ready in the lower console:</font>
```execute
tanzu apps workload get pet-clinic
```

View the newly deployed data in **pgAdmin** (use "chart@example.local/SuperSecret" as login credentials:)
```dashboard:open-url
url: http://pgadmin.{{ ingress_domain }}
```

<font color="red">NOTE: Create a connection to the database by clicking on Servers -> Register -> Server and enter the following:</font>
```execute
printf "Under General tab:\n  Server: pginstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: pginstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: pginstance-1\n  Username: $(kubectl get secret pginstance-1-app-user-db-secret -n {{session_namespace}} -o jsonpath='{.data.username}' | base64 --decode)\n  Password: $(kubectl get secret pginstance-1-app-user-db-secret -n {{session_namespace}} -o jsonpath='{.data.password}' | base64 --decode)\n"
```

#### Inspecting Service Binding in the Workload
The **Service Binding** specification works by volume mounting the secrets delivered by the **Provisioned Service** resource(s) 
into the Workload's pod container(s). The secrets are mounted at a dynamically named directory. An environment variable, 
called SERVICE_BINDING_ROOT, points to the root of the mount directory.

Start a shell session in the workload's container: (<font color="red">NOTE: The directory should contain the subfolder **db**, which is the binding name</font>):
```execute
clear && export MY_SERVICE_BINDING_CTR=$(tanzu apps workload get pet-clinic | grep -e "pet-clinic.*Running\s\+0" | tail -n 1 | cut -d' ' -f1); kubectl exec $MY_SERVICE_BINDING_CTR -it -c workload -- bash
```

Next, view the Service Binding directory's content:
```execute
echo "Service Bindng Mount Path: $SERVICE_BINDING_ROOT"; ls -ltr $SERVICE_BINDING_ROOT/db
```

View specific entries - for example, **type** and **provider** are required by the spec, **username** is optional:
```execute
echo Type: $(cat $SERVICE_BINDING_ROOT/db/type); echo Provider: $(cat $SERVICE_BINDING_ROOT/db/provider); echo Username: $(cat $SERVICE_BINDING_ROOT/db/username); exit
```

#### Integrating Workloads with Service Bindings using Resource Claims
**Services Toolkit** includes the notion of a **Resource Claim**. A **Resource Claim** represents a request
to access a specific **Provisioned Service**, and it is a Custom Resource which also conforms to the **Provisioned Service** spec (similar to
**Service Bindings**). The requested service must match the criteria specified by the claim.
Once matched, a **Service Binding** will be created for the service. **Resource Claims** are the recommended approach for
creating **Service Bindings**, as it enforces decoupling between the application and the service being claimed.

Let's deploy a new version of the **Workload**: this time, we will use **Resource Claims** instead of binding to the **Service Resource** 
directly. 

Create the **Resource Claim** which will be referenced by the **Service Binding** <font color="red">NOTE: Use **tanzu cli** here; however, this can also be accomplished via declarative YAML files.</font>
```execute
clear && tanzu init && tanzu plugin install --local bin/cli services && tanzu service claim create db2 --resource-name pginstance-1 --resource-namespace {{ session_namespace }} --resource-kind Postgres --resource-api-version sql.tanzu.vmware.com/v1
```

View the details of the **Resource Claim** that was created:
```execute
kubectl get resourceclaim db2 -oyaml
```

Notice that the **Resource Claim** references the Postgres DB secret in its **status.binding.name** field. View more details about the secret:
```execute
kubectl get secret pginstance-1-app-user-db-secret -oyaml
```

By default, the **Resource Claim** can only be claimed by Workload resources in the same namespace. 
Expose the **Resource Claim** to other namespaces for consumption by deploying a new **ResourceClaimPolicy** - shown here:
```editor:open-file
file: ~/other/resources/postgres/postgres-tap-resourceclaimpolicy.yaml
```

Create the **ResourceClaimPolicy**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-tap-resourceclaimpolicy.yaml
```

Now the Postgres DB should be consumable in other namespaces. To demonstrate, create a new namespace:
```execute
kubectl create ns test-{{session_namespace}} --dry-run=client -oyaml | kubectl apply -f -
```

Prepare to deploy a new Workload (including setting up RBAC permissions and exporting the registry secret to the new namespace):
```execute
kubectl apply -f ~/other/resources/tap/rbac.yaml -n test-{{session_namespace}}; tanzu secret registry add regsecret --username {{ DATA_E2E_REGISTRY_USERNAME }} --password {{ DATA_E2E_REGISTRY_PASSWORD }} --server {{ DATA_E2E_REGISTRY_USERNAME }} --export-to-all-namespaces --yes --namespace test-{{session_namespace}}; tanzu secret registry add tap-registry --username {{ DATA_E2E_REGISTRY_USERNAME }} --password {{ DATA_E2E_REGISTRY_PASSWORD }} --server {{ DATA_E2E_REGISTRY_USERNAME }} --export-to-all-namespaces --yes --namespace test-{{session_namespace}}; kubectl annotate ns test-{{session_namespace}} secretgen.carvel.dev/excluded-from-wildcard-matching- ; kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "tap-registry"},{"name": "regsecret"}],"secrets":[{"name": "tap-registry"},{"name": "regsecret"}]}' -n test-{{session_namespace}}; kubectl delete workload ext-pet-clinic --namespace test-{{session_namespace}} --ignore-not-found=true;
```

Using the **Apps** plugin of **tanzu cli** this time, create a workload in the new namespace, and bind to the ResourceClaim created above:
```execute
tanzu apps workload create ext-pet-clinic --namespace test-{{session_namespace}} --image "index.docker.io/oawofolu/pet-clinic-data-samples-w03-s001@sha256:0d0af5b3812afcb19efe8565ebb38068eb62c1e5c0cfa2fc05421b037a3314d5" --service-ref "db2=sql.tanzu.vmware.com/v1:Postgres:pginstance-1" --type web --label app.kubernetes.io/part-of=ext-pet-clinic --yes --tail
```
{% endif %}

{% if ENV_WORKSHOP_TOPIC == 'temp' %}
Tail the logs of the newly deployed **Workload**.
<font color="red">NOTE: It may take over a minute for the logs to show up. Hit **Ctrl-C** to exit once the deployment completes</font>:
```execute
tanzu apps workload tail ext-pet-clinic --namespace test-{{session_namespace}} --since 64h
```

Get the app details once deployment completes:
```execute
tanzu apps workload get ext-pet-clinic --namespace test-{{session_namespace}}
```

##### Services Toolkit RBAC
<font color="red">TODO</font>

##### Multi-Cluster Operations with Services Toolkit
<font color="red">ROADMAP ITEM (not yet GA)</font>

##### Monitoring With Datadog:
Set up the Datadog agent for Kubernetes with Prometheus Autodiscovery enabled:
```editor:open-file
file: ~/other/resources/datadog/data-dog.yaml
```

Deploy the Datadog agent:
```execute
clear && helm repo add datadog https://helm.datadoghq.com && helm repo update && helm install datadog -f ~/other/resources/datadog/data-dog.yaml --set datadog.site='datadoghq.com' --set datadog.apiKey='{{DATA_E2E_DATADOG_API_KEY}}' datadog/datadog
```

View the System Overview dashboard:
```dashboard:open-url
url: https://app.datadoghq.com/dash/integration/system_overview
```

Next, redeploy the Datadog agent with Postgres integrations:
```execute
clear; helm uninstall datadog; sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/datadog/data-dog-with-db-config.yaml && helm install datadog -f ~/other/resources/datadog/data-dog-with-db-config.yaml --set datadog.site='datadoghq.com' --set datadog.apiKey='{{DATA_E2E_DATADOG_API_KEY}}' datadog/datadog
```

(NOTE: When prompted, use the credentials below to login:)
```execute
printf "Username: {{DATA_E2E_DATADOG_USER}}\nPassword:{{DATA_E2E_DATADOG_PASSWORD}}"
```
View the Postgres dashboard (<font color="red">TODO: Complete integration so that data is populated</font>):
```dashboard:open-url
url: https://app.datadoghq.com/screen/integration/235/postgres---overview?_gl=1*oqjti6*_gcl_aw*R0NMLjE2NDUyMTkzNTEuQ2owS0NRaUFwTDJRQmhDOEFSSXNBR01tLUtINlZnZ0dZelhOSTdadV8zNlBLMENHbFpjQS1TX2FmOG40ck1zSEVrTXVFa2RpZFB5RnI4UWFBanozRUFMd193Y0I.*_ga*MTI3MDQ4ODI1OC4xNjQ1MTQwNDky*_ga_KN80RDFSQK*MTY0NTgzMDU0OC43LjEuMTY0NTgzMDU1My4w&_ga=2.224920799.418082025.1645749670-1270488258.1645140492&_gac=1.128815230.1645219351.Cj0KCQiApL2QBhC8ARIsAGMm-KH6VggGYzXNI7Zu_36PK0CGlZcA-S_af8n4rMsHEkMuEkdidPyFr8QaAjz3EALw_wcB
```

##### Monitoring With Wavefront:
<font color="red">TODO</font>

##### Secret Management with Vault
<font color="red">TODO</font>
{% endif %}

