#!/bin/bash

source .env

# Create SCDF secrets
kubectl create secret docker-registry scdf-image-regcred --namespace=default \
        --docker-server=$DATA_E2E_GIT_TAP_REGISTRY_SERVER \
        --docker-username="$DATA_E2E_REGISTRY_USERNAME" \
        --docker-password="$DATA_E2E_REGISTRY_PASSWORD" \
        --dry-run -o yaml | kubectl apply -f -

kubectl create secret docker-registry scdf-pivotal-image-regcred --namespace=default \
        --docker-server=dev.registry.pivotal.io \
        --docker-username="$DATA_E2E_PIVOTAL_REGISTRY_USERNAME" \
        --docker-password="$DATA_E2E_PIVOTAL_REGISTRY_PASSWORD" \
        --dry-run -o yaml | kubectl apply -f -

# Install SCDF
other/resources/scdf/bin/install-dev-carvel.sh

# Deploy HttpProxy for SCDF Server
kubectl apply -f other/resources/scdf/scdf-http-proxy.yaml