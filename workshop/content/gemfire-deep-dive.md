Now we will cover the following:

### Multi-Site Replication
**Tanzu Gemfire** supports low-latency, consistent multi-site replication across geographically distributed data centers or regions.
In order to implement it, we need to configure a **GatewaySender** on the primary site (or sites), which will forward any 
subscribable events to a local **GatewaySender** queue. 
Similarly, we need to configure any secondary site (or sites) to listen for connections from the primary site's **GatewaySender** queue; this is done by configuring 
a **GatewayReceiver** on the secondary site(s).

Let's create the site with the **GatewayReceiver** first. (A best practice is to start up consumers before producers, so that emitted events from the producer 
would not be missed.)

Here is the manifest that would be used to configure the **GatewayReceiver**:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver.yaml
text: "start-dev-rest-api"
after: 3
```

Deploy the new site:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver.yaml
```

Create the **GatewayReceiver**:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire2-locator-0 -- gfsh -e connect -e "create gateway-receiver --start-port=13000 --end-port=14000 --hostname-for-senders=gemfire2-server.{{ session_namespace }}.svc.cluster.local"
```

Create a new region, *customers*, which will match the producing region on the sending side:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire2-locator-0 -- gfsh -e connect -e "create region --name=customers --type=PARTITION"
```

Next, let's update the previously existing with the **GatewaySender** - here is the manifest:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender.yaml
text: "start-dev-rest-api"
after: 3
```

Update the sending cluster:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender.yaml
```

Configure the **GatewaySender**:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "create gateway-sender --id=sender1 --parallel=true --remote-distributed-system-id=2"
```

Create a new region, *customers*, which will stream events to the GatewaySender's queue:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "create region --name=customers --type=PARTITION --gateway-sender-id=sender1"
```

Show the list of configured gateways:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "list gateways"
```

### WAN Replication
Now, we will demonstrate the same multi-site replication across geographically distributed regions, i.e. **WAN Replication**. Tanzu Gemfire 
provides robust, native support for WAN replication. The deployment process will be mostly identical,
except that we will need to define **remote-locators** which each cluster will use for discovering remote sites to potentially connect to. 

This will be a topology whereby a primary site in Los Angeles (**us-west**) is configured for one-way replication to a secondary readonly site
in New York (**us-east**). Other topologies such as **ring** and **full-mesh** are also supported. 

Here is the configuration for the primary West site: 
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-la.yaml
text: "jvmOptions"
after: 2
```

In order to allow sites from remote networks to connect, there needs to be some kind of infrastructure in place that will allow cross-regional communication.
Here, we will use **Istio Gateway** to set up a LoadBalancer entrypoint at the cluster's edge. Here is the gateway's manifest:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-istio-la.yaml
```

Deploy the West site with the Istio Gateway:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-istio-la.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-la.yaml -n {{ session_namespace }} && export ISTIO_INGRESS_HOST_WEST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') &&  sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_WEST}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-la.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-la.yaml
```

Next, we will create a Gemfire Cluster in our secondary East site:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml
text: "remote-locators"
```

Notice the line with the **remote-locators** field. This will provide the locators for the West region, which the East site will query to find out about 
connected Gateway Sender, Async Event Queues etc. Update the **remote-locators** field with the locator info for the West site, using the newly generated 
Istio Gateway:
```execute
sed -i "s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_WEST[10334]/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml
```

Deploy the East site (<font color="red">NOTE: Click **Ctrl-C** after the locator and server nodes show up as Ready:</font>)
```execute
(kubectl get secret kconfig -n default -o jsonpath="{.data.myfile}" | base64 --decode) > mykubeconfig && kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl create ns {{session_namespace}} --kubeconfig mykubeconfig;  sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-istio-ny.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-ny.yaml  --namespace={{session_namespace}} --kubeconfig=mykubeconfig && export ISTIO_INGRESS_HOST_EAST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --kubeconfig=mykubeconfig);  kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply --kubeconfig=mykubeconfig -f - && sed -i "s/SECONDARY_ISTIO_INGRESS_HOSTNAME/$ISTIO_INGRESS_HOST_EAST/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml --namespace={{session_namespace}} --kubeconfig=mykubeconfig; watch kubectl get pods -n {{session_namespace}} --kubeconfig=mykubeconfig; kubectl config use-context eduk8s
```

Create the **GatewayReceiver**:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig && kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e connect -e "create gateway-receiver --start-port=13000 --end-port=14000 --hostname-for-senders=$ISTIO_INGRESS_HOST_EAST" && kubectl config use-context eduk8s
```

Create a new region, *posts*, which will match the producing region on the sending side:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig && kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e connect -e "create region --name=posts --type=PARTITION"; kubectl config use-context eduk8s
```

Update the West Site with the **remote-locator** info for the East site:
```execute
sed -i "s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_EAST[10334]/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-la.yaml
```

Configure the **GatewaySender** in the **West** site:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e connect -e "create gateway-sender --id=sender1 --parallel=true --remote-distributed-system-id=2"
```

Create a new region, *posts*, which will stream events to the GatewaySender's queue:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e connect -e "create region --name=posts --type=PARTITION --gateway-sender-id=sender1"
```

Show the list of configured gateways:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e connect -e "list gateways"
```


### Gemfire and NoSQL

#### Gemfire REST API

#### PDX Serialization

#### Integration with GraphQL

#### Scaling and Replication for NoSQL workloads