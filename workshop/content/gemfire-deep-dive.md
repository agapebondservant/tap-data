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
text: "readSerialized: true"
after: 6
```

Deploy the new site:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver.yaml
```

Create the **GatewayReceiver** <font color="red">(NOTE: Wait for the **gemfire2** cluster to show all pods as "Ready" before proceeding:)</font>
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
text: "readSerialized: true"
after: 6
```

Update the sending cluster:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender.yaml
```

Configure the **GatewaySender**  <font color="red">(NOTE: Wait for the **gemfire1** cluster to restart by showing all pods as "Ready" before proceeding:)</font>
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "create gateway-sender --id=sender1 --parallel=true --remote-distributed-system-id=2"
```

Create a new region, *customers*, which will stream events to the GatewaySender's queue:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "create region --name=customers --type=PARTITION --gateway-sender-id=sender1"
```

Show the list of configured gateways:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh -e connect -e "set variable --name=APP_RESULT_VIEWER --value=90000" -e "list gateways"
```

### WAN Replication
Now, we will demonstrate the same multi-site replication across geographically distributed regions, i.e. **WAN Replication**. Tanzu Gemfire 
provides robust, native support for WAN replication. The deployment process will be mostly identical,
except that we will need to define **remote-locators** which each cluster will use for discovering remote sites to potentially connect to. 

This will be a topology whereby a primary site in one region is configured for one-way replication to a secondary readonly site 
in a different region. 
Other topologies such as **ring** and **full-mesh** are also supported. 

Here is the configuration for the primary site: 
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml
text: "jvmOptions"
after: 2
```

#### Set up cross-cluster communication via Istio Gateway on the primary site, including remote locator information
In order to allow sites from remote networks to connect, there needs to be some kind of infrastructure in place that will allow cross-regional communication.
Here, we will use **Istio Gateway** to set up a LoadBalancer entrypoint at the cluster's edge. Here is the gateway's manifest:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-istio-primary.yaml
```

Deploy the Primary site with the Istio Gateway:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-istio-primary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-primary.yaml -n {{ session_namespace }} && export ISTIO_INGRESS_HOST_PRIMARY=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') &&  sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_PRIMARY}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml
```

#### Deploy the secondary cluster with the Gateway Receiver, Istio Gateway and up-to-date remote locator information
Next, we will create a Gemfire Cluster in our secondary site:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml
text: "remote-locators"
```

Notice the line with the **remote-locators** field. This will provide the locators for the Primary region, which the Secondary site will query to find out about 
connected Gateway Sender, Async Event Queues etc. 

Update the **remote-locators** field with the locator info for the Primary site, using the newly generated 
Istio Gateway. <font color="red">(NOTE: Wait for the **gemfire0** cluster to show all pods as "Ready" before proceeding:)</font>
```execute
sed -i "s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_PRIMARY[10334]/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml
```

Deploy the Secondary site (<font color="red">NOTE: Click **Ctrl-C** after the locator and server nodes show up as Ready:</font>)
```execute
(kubectl get secret kconfig -n default -o jsonpath="{.data.myfile}" | base64 --decode) > mykubeconfig && kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl delete gemfirecluster gemfire0 -n {{session_namespace}} --kubeconfig=mykubeconfig || true; kubectl create ns {{session_namespace}} --kubeconfig mykubeconfig || true;  sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-istio-secondary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-secondary.yaml  --namespace={{session_namespace}} --kubeconfig=mykubeconfig && export ISTIO_INGRESS_HOST_SECONDARY=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --kubeconfig=mykubeconfig);  kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply --kubeconfig=mykubeconfig -f - && sed -i "s/SECONDARY_ISTIO_INGRESS_HOSTNAME/$ISTIO_INGRESS_HOST_SECONDARY/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml --namespace={{session_namespace}} --kubeconfig=mykubeconfig; watch kubectl get pods -n {{session_namespace}} --kubeconfig=mykubeconfig; kubectl config use-context eduk8s
```

Create the **GatewayReceiver**:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "destroy gateway-receiver" -e "create gateway-receiver --start-port=13000 --end-port=14000 --hostname-for-senders=$ISTIO_INGRESS_HOST_SECONDARY" -e "set variable --name=APP_RESULT_VIEWER --value=90000"; kubectl config use-context eduk8s
```

Show the list of configured gateways:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=90000" -e "list gateways"; kubectl config use-context eduk8s
```

Create a new region, *claims*, which will match the producing region on the sending side:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "create region --name=claims --type=PARTITION"; kubectl config use-context eduk8s
```

#### Configure the Gateway Sender with up-to-date remote locator information 
#### **NOTE: as a best practice, should start after Gateway Receiver**
Update the Primary Site with the **remote-locator** info for the Secondary site:
```execute
sed -i "s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_SECONDARY[10334]/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml
```

Configure the **GatewaySender** in the **Primary** site:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create gateway-sender --id=sender1 --parallel=true --remote-distributed-system-id=2"
```

Create a new region, *claims*, which will stream events to the GatewaySender's queue:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create region --name=claims --type=PARTITION --gateway-sender-id=sender1"
```

Show the list of configured gateways:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=90000" -e "list gateways"
```

#### Deploy the CacheListener for Oracle Write-Through
Tanzu Gemfire supports event handling for various event-generating operations: region updates, new cache entries, etc.
Here, we will implement the **CacheListener** adapter to synchronously update a backend Oracle database when the **claims** region is updated.
This will occur in both the primary and secondary sites, hence enabling an active-active Oracle setup. 

Here is the **CacheListener** to be deployed:
```editor:select-matching-text
file: ~/other/resources/gemfire/java-source/src/main/java/com/vmware/multisite/SyncOracleCacheListener.java
text: "public void afterCreate"
after: 26
```

Build the **CacheListener** jar file for the **primary** site, and deploy it to the primary cluster:
```execute
cd ~/other/resources/gemfire/java-source; ./mvnw -s settings.xml clean package -Ddemo.resources.dir=src/main/resources/primary; cd ~; kubectl cp ~/other/resources/gemfire/java-source/target/gemfire-multisite-poc-1.0-SNAPSHOT.jar  {{session_namespace}}/gemfire0-locator-0 :/tmp; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "deploy --jars=/tmp/gemfire-multisite-poc-1.0-SNAPSHOT.jar"
```

Now that the **CacheListener** is in the cluster's classpath, we can register it with the **claims** region:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "alter region --name=claims --cache-listener=com.vmware.multisite.SyncOracleCacheListener"
```

Similarly, build the **CacheListener** jar file for the **secondary** site and deploy to the secondary cluster:
```execute
cd ~/other/resources/gemfire/java-source; ./mvnw -s settings.xml clean package -Ddemo.resources.dir=src/main/resources/secondary; cd ~; kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl cp ~/other/resources/gemfire/java-source/target/gemfire-multisite-poc-1.0-SNAPSHOT.jar  {{session_namespace}}/gemfire0-locator-0 :/tmp --kubeconfig mykubeconfig; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "deploy --jars=/tmp/gemfire-multisite-poc-1.0-SNAPSHOT.jar"; kubectl config use-context eduk8s
```

Register the **CacheListener** with the **claims** region in the **secondary** site:
```execute
kubectl config use-context secondary-ctx --kubeconfig=mykubeconfig; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "alter region --name=claims --cache-listener=com.vmware.multisite.SyncOracleCacheListener"; kubectl config use-context eduk8s
```

### Gemfire and NoSQL

#### Gemfire REST API

#### PDX Serialization

#### Integration with GraphQL

#### Scaling and Replication for NoSQL workloads