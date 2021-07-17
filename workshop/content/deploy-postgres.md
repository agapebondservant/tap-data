
### Deploying Tanzu Postgres

**Tanzu Postgres** is a _full-featured_ object-relational data store.

Let's deploy the Tanzu Postgres **operator**:

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm install postgres ~/other/resources/postgres/operator -f ~/other/resources/postgres/overrides.yaml --set tmpNamespace=default
```

Next, let's deploy a highly available Tanzu Postgres **cluster**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster.yaml -n {{ session_namespace }}
```