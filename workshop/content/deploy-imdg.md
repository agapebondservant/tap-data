
### Deploying Tanzu Gemfire

**Tanzu Gemfire** is a _blazing fast_, _highly available_, _consistent_ and _elastically scalable_ in-memory data grid.

Let's deploy the Tanzu Gemfire **operator**:

```execute
kubectl create ns gemfire-{{ session_namespace }}-system --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace=gemfire-{{ session_namespace }}-system --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall  gemfire --namespace gemfire-{{ session_namespace }}-system; helm install gemfire ~/other/resources/gemfire/gemfire-operator-1.0.1.tgz --namespace gemfire-{{ session_namespace }}-system
```

Next, let's define our Gemfire **cluster**. 
```editor:open-file
file: ~/other/resources/gemfire/gemfire-cluster.yaml
```

Our Gemfire cluster is distributed by default: it will consist of a master node, called the locator node (for service discovery, JMX management etc), and 2 server nodes. Later, we will scale out our cluster and create a new region.

Let's go ahead and deploy our Gemfire cluster:
```execute
kubectl create ns gemfire-{{ session_namespace }}-cluster --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace=gemfire-{{ session_namespace }}-cluster --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster.yaml -n gemfire-{{ session_namespace }}-cluster
```

Notice the order in which the cluster members are created, as well as how the nodes are named. The Gemfire cluster leverages the Kubernetes **StatefulSet** for deploying its members. This brings several advantages: for example, it is able to leverage the StatefulSet's ordinal-based naming convention. With StatefulSets, pods are given ordinal suffixes which are incremented based on their startup order, starting from 0. The Gemfire operator uses this pattern to its advantage: the pods with the lowest ordinal suffixes are automatically set up as the **locator** nodes, while the other pods become the **server** nodes. 

Next, we wil launch the **gfsh** cli. **gfsh** is an interface that can be used for the lifecycle management and monitoring of Gemfire resources, including clusters and their members (locators/servers).
```execute
kubectl -n gemfire-{{ session_namespace }}-cluster exec -it gemfire1-locator-0 -- gfsh
```

Connect  to the local Gemfire cluster:
```execute
connect
```

List the members of our newly created cluster:
```execute
list  members
```