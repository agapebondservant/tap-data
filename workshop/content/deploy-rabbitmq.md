
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

Next, let's deploy a highly available Tanzu RabbitMQ **cluster**. First deploy a cluster with just 1 replica:
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

We can also view the Management UI, which is also pre-integrated with the Tanzu RabbitMQ operator.
```dashboard:create-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}.{{ ingress_domain }}
```

To login, you need the UI credentials:
```execute
kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.default_user\.conf}" | base64 --decode
```

Next, scale the cluster to 3 replicas (odd number is recommended). Run the following and edit to include <b>3 replicas</b>:
```execute
kubectl edit rabbitmqcluster rabbitcluster1 -n {{ session_namespace }}
```