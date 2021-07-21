
### Deploying Tanzu Postgres

Let's view our **Petclinic app**. First, we launch it:
```execute
kubectl delete deployment petclinic-app --ignore-not-found=false --namespace={{ session_namespace }} && kubectl delete svc petclinic-app --ignore-not-found=false --namespace={{ session_namespace }} && kubectl create deployment petclinic-app --image=oawofolu/spring-petclinic:1.0 --replicas=2 --namespace={{ session_namespace }} && kubectl expose deployment/petclinic-app --name petclinic-app --port=8080 --type=ClusterIP --namespace={{ session_namespace }}
```

Then, we view it:
```dashboard:create-dashboard
name: Petclinic
url: {{ ingress_protocol }}://petclinic-app.{{ session_namespace }}.svc.cluster.local:8080
```

Let's go ahead and add a few new pet owners, then restart the app. We notice that if we restart the app, we lose all of our entries:
```execute
kubectl rollout restart deploy/petclinic-app && kubectl rollout status -w deployment/petclinic-app
```

To resolve this, we will need to provision a persistent data store.

**Tanzu Postgres** is a _full-featured_ object-relational data store.

Let's deploy the Tanzu Postgres **operator**:

<font color="red">NOTE: Do NOT run this if your workshop instance is not the first generated one, i.e. only run for workshop sessions ending in '001'.</font>

```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm install postgres ~/other/resources/postgres/operator -f ~/other/resources/postgres/overrides.yaml --set tmpNamespace=default
```

Next, let's deploy a highly available Tanzu Postgres **cluster**:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster.yaml -n {{ session_namespace }}
```