#### Deploy Operator UI
Clusters can be deployed by using the **Tanzu Operator UI**.

Let's refresh the cluster (this will removing any pre-existing Tanzu SQL operators):
```execute
kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{ session_namespace }} --docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall postgres --namespace default; helm uninstall postgres --namespace postgres-system; helm uninstall postgres --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep postgres | grep -v postgres-operator-default-cluster-role); do kubectl delete clusterrole ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterrolebinding | grep postgres | grep -v postgres-operator-default-cluster-role-binding); do kubectl delete clusterrolebinding ${i} > /dev/null 2>&1; done; for i in $(kubectl get certificate -n cert-manager | grep postgres); do kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterissuer | grep postgres); do kubectl delete clusterissuer ${i} > /dev/null 2>&1; done; for i in $(kubectl get mutatingwebhookconfiguration | grep postgres); do kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get validatingwebhookconfiguration | grep postgres); do kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get crd | grep postgres); do kubectl delete crd ${i} > /dev/null 2>&1; done; helm uninstall mysql --namespace default; helm uninstall mysql --namespace mysql-system; helm uninstall mysql --namespace {{ session_namespace }}; for i in $(kubectl get clusterrole | grep mysql); do kubectl delete clusterrole ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterrolebinding | grep mysql); do kubectl delete clusterrolebinding ${i} > /dev/null 2>&1; done; for i in $(kubectl get certificate -n cert-manager | grep mysql); do kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1; done; for i in $(kubectl get clusterissuer | grep mysql); do kubectl delete clusterissuer ${i} > /dev/null 2>&1; done; for i in $(kubectl get mutatingwebhookconfiguration | grep mysql); do kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get validatingwebhookconfiguration | grep mysql); do kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1; done; for i in $(kubectl get crd | grep mysql); do kubectl delete crd ${i} > /dev/null 2>&1; done; 
```

Deploy the Operator UI:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/operator-ui/tanzu-operator-ui-app.yaml && sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/operator-ui/tanzu-operator-ui-httpproxy.yaml && ( kubectl delete configmap kconfig || true ) && kubectl create configmap kconfig --from-file  ~/.kube/config && kubectl apply -f ~/other/resources/operator-ui/tanzu-operator-ui-app.yaml && kubectl apply -f  ~/other/resources/operator-ui/tanzu-operator-ui-httpproxy.yaml 
```

Run the annotation script. <font color="red"><b>NOTE:</b> Wait for the <b>tanzu-operator-ui-app</ui> pods to show up as "Ready" in the bottom console before proceeding:</font>
```execute
cp ~/other/resources/operator-ui/cli/* /home/eduk8s/bin/ && ~/other/resources/operator-ui/crd_annotations/apply-annotations
```

Now access the Operator UI:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```

#### Discover New Operators
Next, we'll deploy some new operators and annotate them so they can be discovered by the UI.

Deploy the Postgres operator:
```execute
helm install postgres ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}} -f ~/other/resources/postgres/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null; kubectl apply -f ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}}/crds/ 
```

Run the annotation script:
```execute
~/other/resources/operator-ui/crd_annotations/apply-annotations
```

The Postgres panel should appear in the UI:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```

Next, deploy the MySQL operator:
```execute
helm install mysql ~/other/resources/mysql/operator{{DATA_E2E_MYSQL_OPERATOR_VERSION}} -f ~/other/resources/mysql/overrides.yaml --namespace {{ session_namespace }} --wait &> /dev/null
```

Run the annotation script:
```execute
~/other/resources/operator-ui/crd_annotations/apply-annotations
```

The MySQL panel should appear in the UI:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```

#### Discover Service Instances
The Operator UI is able to automatically discover service instances in the Kubernetes cluster.

Deploy a Postgres instance:
```execute
kubectl apply -f ~/other/resources/postgres/postgres-cluster.yaml -n {{ session_namespace }}
```

Similarly, deploy a MySQL instance:
```execute
kubectl apply -f ~/other/resources/mysql/mysql-cluster.yaml -n {{ session_namespace }}
```

Navigate to the Operator UI to view the newly created instances:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```

#### Integrate Non-VMware Operator Services
The Operator UI can be integrated with third-party data services not managed by VMware, such as Redis, MongoDB, etc.

Here we will integrate a Redis standalone instance.

Deploy a Redis instance:
```execute
helm repo add ot-helm https://ot-container-kit.github.io/helm-charts/ && helm uninstall redis-operator --namespace redis-operator || true && kubectl delete ns redis-operator || true && kubectl create ns redis-operator && helm uninstall sample-redis --namespace {{session_namespace}} || true && helm install redis-operator ot-helm/redis-operator --namespace redis-operator && helm install sample-redis ot-helm/redis  --namespace {{session_namespace}}
```

Run the annotation script:
```execute
~/other/resources/operator-ui/crd_annotations/apply-annotations
```

The Redis panel should appear in the UI with the Redis instance:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```

#### Create Service Instances
The Operator UI can be used to create new service instances. 
Select a service type in the left panel, click "Create Instance", and complete and submit the displayed form:
```dashboard:open-url
url: http://operator-ui-{{session_namespace}}.{{ ingress_domain }}
```
