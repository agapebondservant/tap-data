#!/bin/bash

kubectl create ns gemfire-system --dry-run -o yaml | kubectl apply -f -

kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f -

helm uninstall  gemfire --namespace gemfire-system || true

helm install gemfire other/resources/gemfire/gemfire-operator-${DATA_E2E_GEMFIRE_OPERATOR_VERSION}/ --namespace gemfire-system