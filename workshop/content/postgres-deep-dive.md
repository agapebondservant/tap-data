
#### Integrating with TAP
For **TAP** users, the Tanzu Postgres controller makes it easy to take advantage of Kubernetes' **Service Bindings** for seamlessly binding applications
(called **Workloads**) to database instances (called **Services**).

View the manifest for the integration here:
```editor:select-matching-text
file: ~/other/resources/postgres/postgres-tap.yaml
text: "serviceClaims"
after: 5
```

Notice the highlighted section which defines the **Resource Claim** for the Service Binding. The **Resource Claim** represents a request 
to access a specific **Provisioned Service**. The requested service must match the criteria specified by the claim. Once matched, a **Service Binding**
will be created for the service.

{% if ENV_WORKSHOP_TOPIC == 'temp' %}
Create the **Resource Claim** which will be referenced by the **Service Binding**:
```execute
clear && tanzu init && tanzu plugin install --local bin/cli services && tanzu service claim create db --resource-name pginstance-1 --resource-namespace {{ session_namespace }} --resource-kind Postgres --resource-api-version sql.tanzu.vmware.com/v1
```

Expose the **Resource Claim** to other namespaces for consumption by deploying a new **ResourceClaimPolicy** - shown here:
```open-file
file: ~/other/resources/postgres/postgres-tap-resourceclaimpolicy.yaml
```

Create the **ResourceClaimPolicy**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-tap-resourceclaimpolicy.yaml
```
{% endif %}

{% if ENV_WORKSHOP_TOPIC == 'data-with-tap' %}
#### Installing Postgres via the Tanzu cli
The primary approach for installing the **Tanzu Postgres** operator is by using **Helm**. However, **TAP** customers have the benefit of 
installing **Tanzu Postgres** using the **Tanzu cli**. In addition to the standard **Helm** packaging, **Tanzu Postgres** provides 
packaging for the operator that uses **Carvel's** **imgpkg** format, which is deployed via **Carvel's** **kapp-controller**.
This approach allows TAP operators to use the same unified toolchain for managing **Tanzu Postgres** that is used for other TAP packages.

First, confirm that the **Tanzu Data Services** package is available in the target registry that will be used for the install:
```
echo {{ DATA_E2E_REGISTRY_PASSWORD }} | docker login registry-1.docker.io --username={{ DATA_E2E_REGISTRY_USERNAME }} --password-stdin; if docker manifest inspect {{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} > /dev/null ; then echo "{{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} was found"; else echo "{{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} was not found"; fi
```

Next, export the registry secret that will be used to access the target registry:
```
tanzu secret registry add pg-registry-secret --username {{ DATA_E2E_REGISTRY_USERNAME }} --password {{ DATA_E2E_REGISTRY_PASSWORD }} --server {{ DATA_E2E_REGISTRY_USERNAME }} --export-to-all-namespaces --yes --namespace {{session_namespace}}
```

Verify that there is now an exported secret for the target registry:
```
tanzu secret registry list --namespace {{session_namespace}}
```

With that, now we can add a new **Package Repository** to our TAP install:
```
tanzu package repository add tanzu-data-services-repository --url {{ DATA_E2E_REGISTRY_USERNAME }}/tds-packages:{{DATA_E2E_TDS_PACKAGE_VERSION}} --namespace {{session_namespace}}
```

Verify that the new package repository was added:
```
tanzu package available list --namespace {{session_namespace}}
```

View the `values-schema` which enumerates the operator's default properties: 
```
export PG_TANZU_PKG_VERSION=$(tanzu package available list -o json | jq '.[] | select(.name=="postgres-operator.sql.tanzu.vmware.com")["latest-version"]'); tanzu package available get postgres-operator.sql.tanzu.vmware.com/$PG_TANZU_PKG_VERSION --values-schema
```

The operator's default properties may be overriden using a `values.yaml` manifest file:
```editor:open-file
file: ~/other/resources/postgres/postgres-values.yaml
```

Now install the operator:
```
tanzu package install postgres-operator postgres postgres-operator.sql.tanzu.vmware.com --version $PG_TANZU_PKG_VERSION -f ~/other/resources/postgres/postgres-values.yaml --namespace {{session_namespace}}
```
{% endif %}

Create the **Service Binding** by applying the manifest to the cluster:
```execute
clear && cd ~ && kubectl annotate ns {{session_namespace}} secretgen.carvel.dev/excluded-from-wildcard-matching- && kubectl apply -f ~/other/resources/tap/rbac.yaml && tanzu init && tanzu plugin install --local bin/cli apps && tanzu plugin install --local bin/cli services && tanzu secret registry add tap-registry --username {{DATA_E2E_REGISTRY_USERNAME}} --password {{DATA_E2E_REGISTRY_PASSWORD}} --server https://index.docker.io/v1/ --export-to-all-namespaces --yes -n {{session_namespace}} && kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-credentials"},{"name": "tap-registry"}],"secrets":[{"name": "tap-registry"}]}' && kubectl apply -f ~/other/resources/postgres/postgres-tap.yaml
```

Tail the logs of the newly deployed **Workload** <font color="red">NOTE: Hit **Ctrl-C** to exit once the deployment completes</font>:
```execute
tanzu apps workload tail pet-clinic --since 64h
```

View the app details <font color="red">NOTE: Wait until at least one **pet-clinic** pod shows up as Ready in the lower console:</font>
```execute
tanzu apps workload get pet-clinic
```

View the newly deployed data in **pgAdmin**:
```dashboard:open-url
url: http://pgadmin.{{ ingress_domain }}
```

<font color="red">NOTE:</font> Reuse the credentials provided below if needed:
```execute
printf "Under General tab:\n  Server: pginstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: pginstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: pginstance-1\n  Username: $(kubectl get secret pginstance-1-app-user-db-secret -n {{session_namespace}} -o jsonpath='{.data.username}' | base64 --decode)\n  Password: $(kubectl get secret pginstance-1-app-user-db-secret -n {{session_namespace}} -o jsonpath='{.data.password}' | base64 --decode)\n"
```

#### Monitoring Postgres Data (ctd)
Tanzu Postgres provides a set of scrapeable Prometheus endpoints whose metrics can be collected and forwarded to any OpenMetrics backend.

Let's demonstrate this using **Datadog** and **Wavefront**.

##### <i>With Datadog:</i>
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

##### <i>With Wavefront:</i>
<font color="red">TODO</font>

#### Secret Management with Vault
<font color="red">TODO</font>
