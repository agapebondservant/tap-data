#!/bin/bash

echo "Installing Postgres..."

kubectl create secret docker-registry image-pull-secret --namespace=default --docker-username='$DATA_E2E_REGISTRY_USERNAME' \
        --docker-password='$DATA_E2E_REGISTRY_PASSWORD' \
        --dry-run -o yaml | kubectl apply -f -

helm uninstall postgres --namespace default

helm uninstall postgres --namespace {{ session_namespace }}

for i in $(kubectl get clusterrole | grep postgres | grep -v postgres-operator-default-cluster-role)
do
  kubectl delete clusterrole ${i} > /dev/null 2>&1
done

for i in $(kubectl get clusterrolebinding | grep postgres | grep -v postgres-operator-default-cluster-role-binding)
do
  kubectl delete clusterrolebinding ${i} > /dev/null 2>&1
done

for i in $(kubectl get certificate -n cert-manager | grep postgres)
do
  kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1
done

for i in $(kubectl get clusterissuer | grep postgres)
do
  kubectl delete clusterissuer ${i} > /dev/null 2>&1
done

for i in $(kubectl get mutatingwebhookconfiguration | grep postgres)
do
  kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1
done

for i in $(kubectl get validatingwebhookconfiguration | grep postgres)
do
  kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1
done

for i in $(kubectl get crd | grep postgres)
do
  kubectl delete crd ${i} > /dev/null 2>&1
done

helm install postgres ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}} -f ~/other/resources/postgres/overrides.yaml \
      --namespace {{ session_namespace }} --wait &> /dev/null

kubectl apply -f ~/other/resources/postgres/operator{{DATA_E2E_POSTGRES_VERSION}}/crds/

echo "Postgres installed."