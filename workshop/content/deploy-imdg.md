
### Deploying Tanzu Gemfire

**Tanzu Gemfire** is a _blazing fast_, _highly available_, _consistent_ and _elastically scalable_ in-memory data grid.

Let's deploy the Tanzu Gemfire **operator**:

```execute
clear && kubectl create ns gemfire-system --dry-run -o yaml | kubectl apply -f - &&  kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall  gemfire --namespace gemfire-system; helm install gemfire ~/other/resources/gemfire/gemfire-operator-1.0.1.tgz --namespace gemfire-system
```

Next, let's define our Gemfire **cluster**. 
```editor:open-file
file: ~/other/resources/gemfire/gemfire-cluster.yaml
```

Our Gemfire cluster is distributed by default: it will consist of a master node, called the locator node (for service discovery, JMX management etc), and 2 server nodes. Later, we will scale out our cluster and create a new region.

Let's go ahead and deploy our Gemfire cluster:
```execute
kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster.yaml -n {{ session_namespace }}
```

Notice the order in which the cluster members are created, as well as how the nodes are named. The Gemfire cluster leverages the Kubernetes **StatefulSet** for deploying its members. This brings several advantages: for example, it is able to leverage the StatefulSet's ordinal-based naming convention. With StatefulSets, pods are given ordinal suffixes which are incremented based on their startup order, starting from 0. The Gemfire operator uses this pattern to its advantage: the pods with the lowest ordinal suffixes are automatically set up as the **locator** nodes, while the other pods become the **server** nodes. 

Next, let's update  the cluster by exposing the **Developer REST API** interface for Gemfire. We will need it later for our real-time predictive scoring. Here is the manifest:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-devapi.yaml
text: "servers"
after: 16
```

Let's proceed to update the cluster:
```execute
kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-devapi.yaml -n {{ session_namespace }}
```

Next, we wil launch the **gfsh** cli. **gfsh** is an interface that can be used for the lifecycle management and monitoring of Gemfire resources, including clusters and their members (locators/servers).
<font color="red">NOTE: WAIT FOR THE Gemfire Locator to appear before running.</font>
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh
```

Connect  to the local Gemfire cluster:
```execute
connect
```

List the members of our newly created cluster:
```execute
list  members
```

Create a new region: <font color="red">NOTE: You can also create this with gfsh's autocomplete feature.</font>
```execute
create  region --name=clinicalDataModel --type=REPLICATE_PERSISTENT
```

Querying the new region should yield no results:
```execute
query --query="select * from /clinicalDataModel"
```

Exit the gfsh shell:
```execute
exit
```

Clear before proceeding:
```execute
clear
```

<font color="red"><h3>SKIP this section if you are not demonstrating Wavefront.</h3></font>
<h2>WAVEFRONT/TANZU OBSERVABILITY INTEGRATION</h2>
**Tanzu Gemfire** provides out-of-the-box integration with **Wavefront** (Tanzu Observability). On **Kubernetes**, this is enabled via the **Wavefront Collector**, which is an agent that runs on each node to collect and forward metrics to Wavefront. By simply installing the **Wavefront Collector**, 
we should access to a set of pre-defined metrics, dashboards and alerts for Tanzu Gemfire.

First, launch the **Gemfire dashboard**:
```dashboard:create-dashboard
name: Petclinic
url: {{ DATA_E2E_WAVEFRONT_GEMFIRE_DASHBOARD_URL }}
```

Observe that the dashboard is empty. This is because **Wavefront Collector** has not been set up yet. Install **Wavefront Collector** now:
```execute
helm repo add wavefront https://wavefronthq.github.io/helm/ && kubectl create namespace wavefront --dry-run -o yaml | kubectl apply -f - && (helm uninstall wavefront -n wavefront || helm install wavefront wavefront/wavefront --set wavefront.url=https://vmware.wavefront.com --set wavefront.token={{ DATA_E2E_WAVEFRONT_ACCESS_TOKEN }} --set clusterName=tanzu-data-samples-cluster -n wavefront)
```

The **Gemfire dashboard** should be populated with an initial set of metrics now:
```dashboard:reload-dashboard
name: Petclinic
url: {{ DATA_E2E_WAVEFRONT_GEMFIRE_DASHBOARD_URL }}
```

Next, we will populate the **Tanzu Gemfire** cache servers with some **insurance claim** data.
Create a new **partitioned** region called "claims" - first connect to the cluster:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh connect
```

Create the new region:
```execute
create region --name=claims --type=PARTITION_PERSISTENT
```
Exit the gfsh shell:
```execute
exit
```

Clear before proceeding:
```execute
clear
```

Using the Gemfire Developer REST API, generate some data:
```execute
~/other/resources/data/random-claim-generator.py -1 {{ ingress_protocol }}://gemfire1-dev-api.{{ session_namespace }}.svc.cluster.local:7070/gemfire-api/v1/claims &
```

The Wavefront Collector should have forwarded the newly generated to Wavefront:
```dashboard:reload-dashboard
name: Petclinic
url: {{ DATA_E2E_WAVEFRONT_GEMFIRE_DASHBOARD_URL }}
```

Stop the data generation process:
```execute
kill $!
```