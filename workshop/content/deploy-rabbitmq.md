
### Deploying Tanzu RabbitMQ

**Tanzu RabbitMQ** is a _full-featured_ enterprise-grade message broker.

Let's deploy the Tanzu RabbitMQ **operator**:

```execute
kubectl create ns rabbitmq-{{ session_namespace }}-system --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace=rabbitmq-{{ session_namespace }}-system --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" -n rabbitmq-{{ session_namespace }}-system
```

Install the **krew** cli plugin:
```execute
kubectl krew install rabbitmq
```

The **krew** plugin provides a native approach for managing RabbitMQ clusters. View a list of supported commands:
```execute
kubectl rabbitmq help
```

Next, let's deploy a highly available Tanzu RabbitMQ **cluster**:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster.yaml -n rabbitmq-{{ session_namespace }}-system
```