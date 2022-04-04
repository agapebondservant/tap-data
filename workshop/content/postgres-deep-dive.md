
#### Integrating with TAP
For **TAP** users, the Tanzu Postgres controller makes it easy to take advantage of Kubernetes' **Service Bindings** for seamlessly binding applications
(called **Workloads**) to database instances (called **Services**).

View the manifest for the integration here:
```editor:select-matching-text
file: ~/other/resources/postgres/postgres-tap.yaml
text: "serviceClaims"
after: 5
```

Notice the highlighted section which defines the **Service Claim** for the Service Binding. The **Service Claim** represents a request 
to access a specific **Provisioned Service**. The requested service must match the criteria specified by the claim. Once matched, a **Service Binding**
will be created for the service.

Create the **Service Binding** by applying the manifest to the cluster:
```execute
clear && kubectl annotate ns {{session_namespace}} secretgen.carvel.dev/excluded-from-wildcard-matching- && kubectl apply -f ~/other/resources/tap/rbac.yaml && tanzu init && tanzu plugin install --local bin/cli apps && tanzu secret registry add tap-registry --username {{DATA_E2E_REGISTRY_USERNAME}} --password {{DATA_E2E_REGISTRY_PASSWORD}} --server {{DATA_E2E_GIT_TAP_REGISTRY_SERVER}} --export-to-all-namespaces --yes -n {{session_namespace}} && kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-credentials"},{"name": "tap-registry"}],"secrets":[{"name": "registry-credentials"}]}' && kubectl apply -f ~/other/resources/postgres/postgres-tap.yaml
```

View the newly deployed data in **pgAdmin**:
```dashboard:open-url
url: http://pgadmin.{{ ingress_domain }}
```

<font color="red">NOTE:</font> Reuse the credentials provided below if needed:
```execute
printf "Under General tab:\n  Server: pginstance-1.{{session_namespace}}\nUnder Connection tab:\n  Host name: pginstance-1.{{session_namespace}}.svc.cluster.local\n  Maintenance Database: pginstance-1\n  Username: pgadmin\n  Password: $(kubectl get secret pginstance-1-db-secret -n {{session_namespace}} -o jsonpath='{.data.password}' | base64 --decode)\n"
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
