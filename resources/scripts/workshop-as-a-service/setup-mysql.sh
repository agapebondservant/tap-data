#!/bin/bash

echo "Installing MySQL..."

kubectl create ns mysql-system

kubectl create secret docker-registry image-pull-secret --namespace=mysql-system \
--docker-username='$DATA_E2E_REGISTRY_USERNAME' \
--docker-password='$DATA_E2E_REGISTRY_PASSWORD' \
--dry-run -o yaml | kubectl apply -f - 

helm uninstall mysql --namespace mysql-system
for i in $(kubectl get clusterrole | grep mysql) 
do 
  kubectl delete clusterrole ${i} > /dev/null 2>&1
done

for i in $(kubectl get clusterrolebinding | grep mysql) 
do 
  kubectl delete clusterrolebinding ${i} > /dev/null 2>&1
done

for i in $(kubectl get certificate -n cert-manager | grep mysql)
do 
  kubectl delete certificate -n cert-manager ${i} > /dev/null 2>&1
done

for i in $(kubectl get clusterissuer | grep mysql) 
do 
  kubectl delete clusterissuer ${i} > /dev/null 2>&1
done

for i in $(kubectl get mutatingwebhookconfiguration | grep mysql)
do 
  kubectl delete mutatingwebhookconfiguration ${i} > /dev/null 2>&1
done

for i in $(kubectl get validatingwebhookconfiguration | grep mysql) 
do 
  kubectl delete validatingwebhookconfiguration ${i} > /dev/null 2>&1
done

for i in $(kubectl get crd | grep mysql)
do 
  kubectl delete crd ${i} > /dev/null 2>&1
done

helm install mysql other/resources/mysql/operator${DATA_E2E_MYSQL_OPERATOR_VERSION} \
-f other/resources/mysql/overrides.yaml \
--namespace mysql-system --wait &> /dev/null

echo "MySQL installed."