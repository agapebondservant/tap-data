### Deploying Tanzu RabbitMQ - Deep Dive

Now we will cover the following:

#### Standby Replication Operator
Let's deploy the Standby Replication operator:

```execute
kubectl apply -f https://github.com/rabbitmq/messaging-topology-operator/releases/latest/download/messaging-topology-operator-with-certmanager.yaml
```

#### Continuous Schema Replication

#### Standby Message Replication

#### Inter-node Data Compression

#### Vault Integration

Sometimes, the ideal use case is to leverage RabbitMQ transparently as the messaging transport layer, without having to be aware of its inner workings or semantics. For that, we can leverage  **Spring Cloud Data Flow**.