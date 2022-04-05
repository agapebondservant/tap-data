Now we will cover the following:

### Gemfire and NoSQL

### WAN Replication
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


#### Gemfire REST API

#### PDX Serialization

#### Integration with GraphQL

#### Scaling and Replication for NoSQL workloads