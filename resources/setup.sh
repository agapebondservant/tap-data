#!/bin/bash
# Delete pre-existing Greenplum operator and PXF-service
kubectl delete greenplumpxfservice data-e2e-greenplum-pxf --namespace greenplum-system --ignore-not-found=true
kubectl delete greenplumcluster gpdb-cluster-data-samples-w01-s001 --ignore-not-found=true --namespace greenplum-system
helm uninstall greenplum-operator --namespace greenplum-system

# Install  Greenplum operator
kubectl create ns greenplum-system --dry-run -o yaml | kubectl apply -f - && \
kubectl create secret docker-registry image-pull-secret --namespace=greenplum-system \
--docker-username='oawofolu' --docker-password='8ead1438-7b5f-4212-b0c8-7813df575b33' \
--dry-run -o yaml | kubectl apply -f -
helm install greenplum-operator other/resources/greenplum/operator -f other/resources/greenplum/overrides.yaml -n greenplum-system

