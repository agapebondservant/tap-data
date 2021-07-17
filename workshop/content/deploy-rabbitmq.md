
### Deploying Tanzu RabbitMQ

**Tanzu RabbitMQ** is a _full-featured_ enterprise-grade message broker.

Let's deploy the Tanzu RabbitMQ **operator**:

```terminal:execute
command: kubectl create ns rabbitmq-system --dry-run -o yaml | kubectl apply -f - &&  kubectl create secret docker-registry image-pull-secret --namespace=rabbitmq-system --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --namespace=rabbitmq-system
clear: true
```

Install the **krew** cli plugin:
```execute
export PATH="${PATH}:${HOME}/.krew/bin" && kubectl krew install rabbitmq
```

The **krew** plugin provides a native approach for managing RabbitMQ clusters. View a list of supported commands:
```execute
kubectl rabbitmq help
```

Next, let's deploy a highly available Tanzu RabbitMQ **cluster**. First deploy a cluster with just 1 replicas:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-monitor.yaml; kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster.yaml -n {{ session_namespace }}
```

Next, scale the cluster to 2 replicas (odd number is recommended):
```execute
kubectl edit rabbitmqcluster rabbitcluster1 -n {{ session_namespace }}
```