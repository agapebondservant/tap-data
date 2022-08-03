### Deploying Tanzu RabbitMQ - Deep Dive

Now we will walk through a demo of **Realtime Analytics** with Tanzu RabbitMQ.

Show the **User Experience** dashboard app:
```dashboard:open-url
name: Anomalies
url: {{ ingress_protocol }}://anomaly-dashboard.{{ DATA_E2E_BASE_URL }}:8080
```

Show the **User Experience** tracker app:
```dashboard:open-url
name: Tracker
url: {{ ingress_protocol }}://anomaly-tracker.{{ DATA_E2E_BASE_URL }}:8080
```

Show the RabbitMQ Management dashboard -login with credentials **data-user/data-password**:
```dashboard:open-url
name: RabbitMQ
url: {{ ingress_protocol }}://rmqui.{{ DATA_E2E_BASE_URL }}
```