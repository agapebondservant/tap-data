#!/bin/bash

source .env

# Install SCDF
other/resources/scdf/bin/install-dev-carvel.sh

# Deploy HttpProxy for SCDF Server
kubectl apply -f other/resources/scdf/scdf-http-proxy.yaml
