### Deploying Tanzu RabbitMQ - Deep Dive

Now we will cover the following:

### Topology Operator
The Topology operator handles the creation and management of the RabbitMQ entities that belong to a cluster, such as queues, policies, exchanges, users, queue bindings.

Let's deploy the Topology operator:

```execute
kubectl apply -f https://github.com/rabbitmq/messaging-topology-operator/releases/latest/download/messaging-topology-operator-with-certmanager.yaml
```

#### HA Queues
In order to deploy a replicated queue, we need to deploy a queue type that supports **high availability**. For the purposes of this demo, let's start with the oldest replicated queue type, **classic mirrored** queues. Each HA queue will have one leader node and 2 mirror nodes. There is no statically designated leader node for all queues; rather, node selection is based on the configured **queue-master-locator** policy, i.e. *min-leaders*, *client-local*, *random*, etc. The leader node will handle all write (i.e. publish) requests, and the mirror nodes will synchronize their state with the leader node and be able to serve normal consumption requests. As long as the mirror nodes are synchronized with the leader node, any of them can be promoted to become the leader when necessary (if the leader node fails, if the mirror nodes cannot connect to the leader node, etc).

Let's deploy a new **HA queue** - here's the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-ha-classic-queue.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-ha-classic-queue.yaml -n {{ session_namespace }}
```

Observe in the RabbitMQ adminstrative console that the queue has now been created. Publish a message to the queue with routing-key "demo-classic", so that it will be routed via the default exchange. Then kill the primary node. The message still persists once the node recovers.

Meanwhile, notice that our Grafana dashboard has picked up the topology changes. <font color="red">Launch Grafana dashboard</font>

#### Data Safety

Let's return to the definition of our new **Queue**:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-ha-classic-queue.yaml
```

<font color="red">Discussion about data safety</font>

#### Quorum Queues

Quorum queues are a newer type of queue which is more opinionated than classic queues when it comes to data safety and failure recovery. As of RabbitMQ 3.8, they are the preferred approach for replicated queues. Mirrored classic queues are still available for legacy purposes, but they will be retired at some point in the future, so the recommendation is to use quorum queues for use cases where data safety is important.

Let's create a new **Quorum Queue** - here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-ha-quorum-queue.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-ha-quorum-queue.yaml -n {{ session_namespace }}
```

Observe in the RabbitMQ adminstrative console that the queue has now been created. Publish a message to the queue with routing-key "demo-quorum", so that it will be routed via the default exchange. Then kill the primary node. The message still persists once the node recovers.

#### Request-Response vs Publish-Subscribe

#### Exchange Routing

#### Streams 
Tanzu RabbitMQ allows you to create **streams**. Streams are replayable structures which provide features such as scalable fan-out and time-travel.

First, redeploy the RabbitMQ cluster by installing the **Streams** plugin:

```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-with-plugins.yaml -n {{ session_namespace }}
```

Once the **RabbitMQ** node is running, locate the primary RabbitMQ node and type **s** in the lower console window to launch the **RabbitMQ** node's shell: 
```execute-2
s
```

Enable the **Streams** plugin:
```execute-2
rabbitmq-plugins enable rabbitmq_stream
rabbitmqctl enable_feature_flag stream_queue
```

Exit the shell:
```execute-2
exit
```

Create a new Stream, **test-streams**, in the RabbitMQ Admin window (under **Queues** tab):
```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}.{{ ingress_domain }}
```

Publish a random JSON  message - retrieve the payload from here:
```execute
pip install faker && python ~/other/resources/data/random-json-generator.py 10
```