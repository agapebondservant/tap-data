
### Create Data Pipeline

Using the previously created data resources, we will set up a data pipeline using **VMware Spring Cloud Data Flow**. Let's set up a new data pipeline:

```execute
command: kubectl create secret docker-registry scdf-image-regcred --namespace={{ session_namespace }}--docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && other/resources/scdf/configure.sh  && other/resources/scdf/bin/install-dev.sh --monitoring prometheus
clear: true
```