#!/bin/bash
# Delete pre-existing Greenplum operator and PXF-service
kubectl delete greenplumpxfservice data-e2e-greenplum-pxf --namespace greenplum-system --ignore-not-found=true
kubectl delete greenplumcluster --all --ignore-not-found=true --namespace greenplum-system
helm uninstall greenplum-operator --namespace greenplum-system

# Install  Greenplum operator
kubectl create ns greenplum-system --dry-run -o yaml | kubectl apply -f - && \
kubectl label namespaces greenplum-system cert-manager.io/disable-validation=true
kubectl create secret docker-registry image-pull-secret --namespace=greenplum-system \
--docker-username='${DATA_E2E_REGISTRY_USERNAME}' --docker-password='${DATA_E2E_REGISTRY_PASSWORD}' \
--dry-run -o yaml | kubectl apply -f -
helm install greenplum-operator other/resources/greenplum/operator -f other/resources/greenplum/overrides.yaml -n greenplum-system

