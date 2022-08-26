#!/bin/bash

echo "Installing RabbitMQ..."

kubectl create ns rabbitmq-system --dry-run -o yaml | kubectl apply -f -
kubectl apply -f other/resources/rabbitmq/rabbitmq-operator-rbac.yaml -n rabbitmq-system
kubectl create clusterrolebinding tanzu-rabbitmq-crd-install-binding \
    --clusterrole=tanzu-rabbitmq-crd-install \
    --serviceaccount=rabbitmq-system:default -n rabbitmq-system \
    --dry-run -o yaml | kubectl apply -n rabbitmq-system -f -

kubectl create secret docker-registry image-pull-secret --namespace=rabbitmq-system \
--docker-username='{{ DATA_E2E_REGISTRY_USERNAME }}' \
--docker-password='{{ DATA_E2E_REGISTRY_PASSWORD }}' \
--dry-run -o yaml | kubectl apply -f -

sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" other/resources/rabbitmq/rabbitmq-operator-secretexport.yaml
kubectl apply -f other/resources/rabbitmq/rabbitmq-operator-secretexport.yaml

kapp delete -a tanzu-rabbitmq-repo -y -nrabbitmq-system
kapp deploy -a tanzu-rabbitmq-repo -f other/resources/rabbitmq/rabbitmq-operator-packagerepository.yaml -y -nrabbitmq-system

export RABBIT_KAPP_INST=$(kubectl get packageinstall -n rabbitmq-system -ojson | jq '.items[] | .metadata.labels["kapp.k14s.io/app"]' | tr -d '"')
kapp delete -a tanzu-rabbitmq -y -nrabbitmq-system
kubectl get validatingwebhookconfiguration -l kapp.k14s.io/app=$RABBIT_KAPP_INST -o name | xargs -r kubectl delete
kubectl get clusterrolebinding -l kapp.k14s.io/app=$RABBIT_KAPP_INST -o name | xargs -r kubectl delete
kubectl get clusterrole -l kapp.k14s.io/app=$RABBIT_KAPP_INST -o name | xargs -r kubectl delete
kubectl apply -f other/resources/rabbitmq/rabbitmq-operator-packageinstall.yaml -nrabbitmq-system

echo "RabbitMQ installed."