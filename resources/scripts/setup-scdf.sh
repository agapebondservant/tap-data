#!/bin/bash

source .env
echo $DATA_E2E_REGISTRY_PASSWORD | docker login --username=$DATA_E2E_REGISTRY_USERNAME --password-stdin

# Relocate images to container registry
other/resources/scdf/bin/relocate-image.sh --app data-flow --repository $DATA_E2E_GIT_TAP_REGISTRY_REPO/spring-cloud-dataflow-server
other/resources/scdf/bin/relocate-image.sh --app composed-task-runner --repository $DATA_E2E_GIT_TAP_REGISTRY_REPO/spring-cloud-dataflow-composed-task-runner
other/resources/scdf/bin/relocate-image.sh --app skipper --repository $DATA_E2E_GIT_TAP_REGISTRY_REPO/spring-cloud-skipper-server

# Create SCDF imagepullsecret
kubectl create secret docker-registry scdf-image-regcred --namespace=default --docker-server=$DATA_E2E_GIT_TAP_REGISTRY_SERVER --docker-username="$DATA_E2E_REGISTRY_USERNAME" --docker-password="$DATA_E2E_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -

# Install SCDF
other/resources/scdf/bin/install-dev.sh --database postgresql --broker rabbitmq --monitoring none

# Deploy HttpProxy for SCDF Server
kubectl apply -f other/resources/scdf/scdf-http-proxy.yaml

