### Deploying Tanzu RabbitMQ - Deep Dive

Now we will walk through a demo of **Realtime Analytics** with Tanzu RabbitMQ.

Show the **User Experience** dashboard app:
```dashboard:open-url
name: Anomalies
url: {{ ingress_protocol }}://anomaly-{{ session_namespace }}.{{ DATA_E2E_BASE_URL }}
```