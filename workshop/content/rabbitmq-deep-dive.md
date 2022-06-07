### Deploying Tanzu RabbitMQ - Commercial Features

Now we will cover the following:

### Topology Operator
The Topology operator handles the creation and management of the RabbitMQ entities that belong to a cluster, such as queues, policies, exchanges, users, queue bindings.


Let's deploy the Topology operator:
```execute
kubectl apply -f https://github.com/rabbitmq/messaging-topology-operator/releases/latest/download/messaging-topology-operator-with-certmanager.yaml
```

#### Quorum Queues

Quorum queues are a newer type of queue which is more opinionated than classic queues when it comes to data safety and failure recovery. 
As of RabbitMQ 3.8, they are the preferred approach for replicated queues. 
Mirrored classic queues are still available for legacy purposes, but they will be retired at some point in the future, 
so the recommendation is to use quorum queues for use cases where data safety is important.

Let's create a new **Quorum Queue** - here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-ha-quorum-queue.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-ha-quorum-queue.yaml -n {{ session_namespace }}
```

Observe in the RabbitMQ adminstrative console that the queue has now been created. Publish a message to the queue with routing-key **demo.quorum.green**, so that it will be routed via the default exchange. Then kill the primary node. The message still persists once the node recovers.

#### Request-Response vs Publish-Subscribe
A RabbitMQ consumer can register to receive enqueued messages from the RabbitMQ broker using one of two approaches. It can use a push-based approach, or a poll-based approach. The polling-based approach uses a **Basic.Get** RPC operation, which is a synchronous blocking operation and more of a request-response paradigm. 

Go to the **demo.quorum.green** queue on the Queues tab, and click **Get Message** to dequeue the message that was published earlier.

The push-based mode uses the **Basic.Consume** RPC operation, and is the PubSub approach for consuming messages. It is asynchronous, non-blocking, can support multiple consumers at a time in a decoupled manner. The trade-off is that it requires the implementation of consumer acknowledgements and publish confirms in order to guarantee data safety. More on that later.

#### Exchange Routing
RabbitMQ provides four main types of routing through exchanges: **direct**, **fanout**, **topic** and **headers**. 

Normally, in order for a queue to consume messages from the broker, it must be bound to an exchange. There are some nuances to this. On the Exchanges tab, observe that there are some exchanges created by default. In particular, notice the **default** exchange. It is a special kind of direct exchange (with no name) which binds every queue to itself using the queue name as the routing key. In this case, this is why we were able to publish messages to our queues without creating an exchange first. 

In the management UI, create a new **topic exchange** which will route messages with routing key **#.green** to the **demo.quorum.green** queue, and messages with routing key **#.red** to the **demo.classic.red** queue. 

Here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-topic-exchange.yaml
```

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-topic-exchange.yaml
```

Observe in the RabbitMQ adminstrative console that the new exchange has now been created. 


Publish a message to the exchange with routing-key **msg.green**, so that it will be routed to the **demo.quorum.green** queue. Similarly, publish a message to the exchange with routing-key **msg.red**, so that it will be routed to the **demo.quorum.red** queue.

#### Cross-Cluster Distribution
For distributed messaging across clusters, in-built clustering does not suffice. RabbitMQ supports cross-cluster distribution through two approaches: Federation and Shoveling. The right approach always depends on the specific use case.

{% if ENV_WORKSHOP_TOPIC == 'notready' %}

Let's create another cluster, **rabbitcluster2**, that we will use as the downstream for our original cluster. Here's the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-federation.yaml
```

Set up the RabbitMQ admin console for the new cluster:

Create an Ingress for the Management UI:
<font color="red">Wait for the cluster nodes to show up before running</font>
```execute
kubectl wait --for=condition=Ready pod/rabbitcluster2-server-0 -n {{ session_namespace }} && cat ~/other/resources/rabbitmq/rabbitmq-httpproxy.yaml | sed -e s/__TOKEN__/{{ session_namespace }}-2/g | kubectl apply -n {{ session_namespace }} -f -
```

We can also view the Management UI, which is also pre-integrated with the Tanzu RabbitMQ operator.
```dashboard:create-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}-2.{{ ingress_domain }}
```

To login, you need the UI credentials:
```execute
kubectl get secret rabbitcluster2-default-user -o jsonpath="{.data.default_user\.conf}" | base64 --decode
```
{% endif %}

Redeploy the RabbitMQ cluster by installing the **Streams** and **Federation** plugins - here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-with-plugins.yaml
```

Redeploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-with-plugins.yaml -n {{ session_namespace }}
```

Once the **RabbitMQ** node is running, locate the primary RabbitMQ node and type **s** in the lower console window to launch the **RabbitMQ** node's shell: 
```execute-2
s
```

Enable the **Federation** plugin:
```execute-2
rabbitmq-plugins enable rabbitmq_federation
rabbitmq-plugins enable rabbitmq_federation_management
```

```execute-2
exit
```

In order to setup configuration for federation, we will need an **upstream configuration** and a **policy** that tells RabbitMQ how to apply upstream connections and configuration to the downstream. 

#### Streams 
Tanzu RabbitMQ allows you to create **streams**. Streams are replayable structures which provide features such as scalable fan-out and time-travel.

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

Sometimes, the ideal use case is to leverage RabbitMQ transparently as the messaging transport layer, without having to be aware of its inner workings or semantics. For that, we can leverage  **Spring Cloud Data Flow**.