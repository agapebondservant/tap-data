
### Overview

Using the previously created data resources, we will be able to set up a data pipeline using **VMware Spring Cloud Data Flow**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:create-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}/dashboard
```

Let's view the RabbitMQ console for the broker that will be leveraged by our pipelines - login with <i>admin/admin:</i>

```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbitmq.default.svc.local/dashboard
```

Restore the UI for the other RabbitMQ cluster we created earlier.
```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}.{{ ingress_domain }}
```
