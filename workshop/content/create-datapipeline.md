
### Create Data Pipeline

Using the previously created data resources, we will set up a data pipeline using **VMware Spring Cloud Data Flow**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:create-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}
```