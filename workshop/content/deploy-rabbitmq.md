
### Deploying Tanzu RabbitMQ

**Tanzu RabbitMQ** is a _full-featured_ enterprise-grade message broker.

Let's deploy the Tanzu RabbitMQ **operator**:

```execute
clear && kubectl create ns rabbitmq-system --dry-run -o yaml | kubectl apply -f - &&  kubectl create secret docker-registry image-pull-secret --namespace=rabbitmq-system --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --namespace=rabbitmq-system && export DATA_E2E_MY_RABBIT_UI_HOST=$(kubectl get svc rabbitcluster1 -o jsonpath="{.status.loadBalancer.ingress[0]}" -n {{session_namespace}}) &&  export DATA_E2E_MY_RABBIT_UI_USERNAME=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.username}"  -n {{session_namespace}} | base64 --decode) && export DATA_E2E_MY_RABBIT_UI_PASSWORD=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.password}"  -n {{session_namespace}} | base64 --decode)
```

The **krew** plugin provides a native approach for managing RabbitMQ clusters. View a list of supported commands:
```execute
export PATH="${PATH}:${HOME}/.krew/bin" && kubectl krew install rabbitmq  && kubectl rabbitmq help
```

Next, let's deploy a highly available Tanzu RabbitMQ **cluster**. First deploy a cluster with just 1 replica:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-monitor.yaml; kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster.yaml -n {{ session_namespace }};
```

Meanwhile, let's take a look at a pre-built Grafana dashboard. It has been integrated with a Prometheus service which has auto-detected our cluster.
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

We can also view the Management UI, which is also pre-integrated with the Tanzu RabbitMQ operator.
```dashboard:create-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://{{ DATA_E2E_MY_RABBIT_UI_HOST }}:15672
```

To login, you need the UI credentials. Copy the UI username:
```copy
echo "DATA_E2E_MY_RABBIT_UI_USERNAME"
```

Copy the UI password:
```copy
echo "{{DATA_E2E_MY_RABBIT_UI_PASSWORD}}"
```

Next, scale the cluster to 3 replicas (odd number is recommended):
```execute
kubectl edit rabbitmqcluster rabbitcluster1 -n {{ session_namespace }}
```

