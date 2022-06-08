### Deploying Tanzu RabbitMQ - Deep Dive

Now we will cover the following:

#### Deploying via the Operator UI
With **Tanzu RabbitMQ**, brokers/clusters can be deployed by using the **Tanzu Operator UI**. First, refresh the UI settings to ensure that it is in sync with the latest Operator changes:
```execute
~/other/resources/operator-ui/annotate.sh; kubectl annotate pkgi tanzu-rabbitmq ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=rabbitmq-operator-tsqlui-annotation-overlay-secret -nrabbitmq-system --overwrite
```

Now access the Operator UI:
```dashboard:open-url
url: http://operator-ui.{{ ingress_domain }}
```

#### Standby Replication Operator

**Tanzu RabbitMQ** provides a streamlined approach for replication across sites with its **Standby Replication** plugins.
In Kubernetes, these are provided by the Standby Replication Operator. 
The Standby Replication Operator handles automated **schema** and **message** replication to a hot standby cluster.

Without **Tanzu RabbitMQ**, standby replication can be achieved by manually importing the schema from the upstream and using 
one of RabbitMQ's core features for cross-broker/cross-site replication, such as **federation** or **shoveling**. 
However, the core RabbitMQ approach involves several manual steps, and relies on TTL/message throughput estimates for message synchronization 
between upstream and downstream, which can result in data loss and/or data duplication if the estimates were not accurate.
This is mitigated via the commercial **Standby Replication** feature, which uses streaming log updates for an up-to-date view of upstream messages,
and offers an API for automatic promotion of the standby during disaster recovery. Let's explore how.

##### Deploying Upstream and Downstream Clusters
First, we will create a new upstream cluster:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream.yaml
text: "additionalPlugins"
after: 9
```

Notice the **plugins** and **config** that are required for the upstream.

Deploy the upstream cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream.yaml -n {{ session_namespace }}
```

Next, we wil create the entities in the upstream that will be replicated to the downstream using the **Topology operator**.
The Topology operator handles the creation and management of the RabbitMQ entities that belong to a cluster,
such as queues, policies, exchanges, users, queue bindings.

Quorum queues are a newer type of queue which is more opinionated than classic queues when it comes to data safety and failure recovery.
As of RabbitMQ 3.8, they are the preferred approach for replicated queues.
Mirrored classic queues are still available for legacy purposes, but they will be retired at some point in the future,
so the recommendation is to use quorum queues for use cases where data safety is important.

Let's create a new **Quorum Queue** - here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-quorum-queue.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-quorum-queue.yaml -n {{ session_namespace }}
```

Similarly, we create a new downstream cluster which will serve as the hot standby:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstreamstream.yaml
text: "additionalPlugins"
after: 11
```

Deploy the downstream cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream.yaml -n {{ session_namespace }}
```

##### Configuring Schema Replication plugin (upstream)
Next, we will configure the **Schema Replication** plugin, which will take care of **schema replication**. 
First we configure the user that will be used to establish the connection to the upstream.
We do this configuring the user credentials and permissions:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-credsandpermissions.yaml
```

Deploy the new User with its credentials and permissions:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-credsandpermissions.yaml -n {{ session_namespace }}
```

Now we will configure the actual Schema Replication object, including setting up the **upstream endpoint** and **upstream cluster name**:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-schema-object.yaml
```

Deploy the Schema Replication object:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-schema-object.yaml -n {{ session_namespace }}
```

##### Configuring Standby Message Replication plugin (upstream)
After configuring the **Schema Replication** plugin, we will now configure the **Standby Message Replication** plugin, 
which will take care of **message replication** to the standby. In our case, we will reuse the User created for Schema Replication above.

We configure it by setting up a **replication policy** which will be used to replicate from the upstream:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-message-object.yaml
```
Here, the replication policy will replicate *all* quorum queues from the **test** vhost.

Deploy the Standby Message Replication object:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-message-object.yaml -n {{ session_namespace }}
```

##### Configuring downstream (Schema Replication and Standby Message Replication plugin)
Now that we have configured the upstream cluster, we will configure the downstream to receive replicated schema and messages from the upstream.
Similarly to before, we will configure the **Schema Replication** plugin for the downstream.
Here is the manifest (in our case, we will reuse the replication user credentials from the upstream):
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-credsandpermissions.yaml
```

Deploy the new downstream User with its credentials and permissions:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-credsandpermissions.yaml -n {{ session_namespace }}
```

Similarly, we will configure the **Standby Message Replication** plugin for the downstream.
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-message-object.yaml
```

Deploy the Standby Message Replication object:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-message-object.yaml -n {{ session_namespace }}
```

#### Inter-node Data Compression


Sometimes, the ideal use case is to leverage RabbitMQ transparently as the messaging transport layer, without having to be aware of its inner workings or semantics. For that, we can leverage  **Spring Cloud Data Flow**.