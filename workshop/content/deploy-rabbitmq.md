
### Deploying Tanzu RabbitMQ

**Tanzu RabbitMQ** is a _full-featured_ enterprise-grade message broker.

Let's deploy the Tanzu RabbitMQ **operator**:

```execute
clear && kubectl create ns rabbitmq-system --dry-run -o yaml | kubectl apply -f - &&  kubectl create secret docker-registry image-pull-secret --namespace=rabbitmq-system --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --namespace=rabbitmq-system
```

The **krew** plugin provides a native approach for managing RabbitMQ clusters. View a list of supported commands:
```execute
export PATH="${PATH}:${HOME}/.krew/bin" && kubectl krew install rabbitmq  && kubectl rabbitmq help
```

Next, let's deploy a highly available Tanzu RabbitMQ **cluster**. Here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster.yaml
```

First deploy a cluster with just 1 replica:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-monitor.yaml; kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster.yaml -n {{ session_namespace }};
```

Create an Ingress for the Management UI:
<font color="red">Wait for cluster nodes to show up before running</font>
```execute
kubectl wait --for=condition=Ready pod/rabbitcluster1-server-0 -n {{ session_namespace }} && cat ~/other/resources/rabbitmq/rabbitmq-httpproxy.yaml | sed -e s/__TOKEN__/{{ session_namespace }}/g | kubectl apply -n {{ session_namespace }} -f -
```

Meanwhile, let's take a look at a pre-built Grafana dashboard. It has been integrated with a Prometheus service which has auto-detected our cluster.
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

<font color="red">Use the credentials below to login to the Grafana dashboard:</font>
```execute
printf "Username: admin\nPassword: $(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)\n"
```

We can also view the Management UI, which is also pre-integrated with the Tanzu RabbitMQ operator.
```dashboard:create-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}.{{ ingress_domain }}
```

To login, you need the UI credentials:
```execute
kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.default_user\.conf}" | base64 --decode
```

{% if WORKSHOP_TOPIC == 'data-file-ingestion' %}
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

Return  to the pod view.
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

{% endif %}

Next, let's scale the cluster to 3 replicas (odd number is recommended). In the vim editor that comes up, edit the number of replicas from 1 to 3 (replace the phrase **replicas: 1**):
```execute
kubectl edit rabbitmqcluster rabbitcluster1 -n {{ session_namespace }}
```

{% if WORKSHOP_TOPIC == 'data-file-ingestion' %}
Sometimes, the ideal use case is to leverage RabbitMQ transparently as the messaging transport layer, without having to be aware of its inner workings or semantics. For that, we will leverage  **Spring Cloud Data Flow**:
```dashboard:open-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}/dashboard
```

We will build a file ingestion pipeline next.
{% endif %}