
#!/bin/bash

# Set variables
export DATA_E2E_POSTGRES_HOSTNAME=$(kubectl get svc pginstance-1 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' -n $SESSION_NAMESPACE)
export DATA_E2E_POSTGRES_DB=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' -n $SESSION_NAMESPACE | base64 --decode)
export DATA_E2E_POSTGRES_USERNAME=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' -n $SESSION_NAMESPACE | base64 --decode) 
export DATA_E2E_POSTGRES_PASSWORD=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' -n $SESSION_NAMESPACE | base64 --decode)

export DATA_E2E_RABBITMQ_HOSTNAME=$(kubectl get svc rabbitcluster1 -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"  -n $SESSION_NAMESPACE)
export DATA_E2E_RABBITMQ_PORT=$(kubectl get svc rabbitcluster1 -o jsonpath="{.status.loadBalancer.ingress[0].port}"  -n $SESSION_NAMESPACE)
export DATA_E2E_RABBITMQ_USERNAME=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.username}"  -n $SESSION_NAMESPACE | base64 --decode)
export DATA_E2E_RABBITMQ_PASSWORD=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.password}"  -n $SESSION_NAMESPACE | base64 --decode)

export DATA_E2E_SCDF_DATAFLOW_PATH=~/other/resources/scdf/apps/data-flow/kustomize/overlays/
export DATA_E2E_SCDF_DATAFLOW_BASE_PATH=~/other/resources/scdf/apps/data-flow/kustomize/base
export DATA_E2E_SCDF_SKIPPER_PATH=~/other/resources/scdf/apps/skipper/kustomize/overlays/
export DATA_E2E_SCDF_SKIPPER_BASE_PATH=~/other/resources/scdf/apps/skipper/kustomize/base

sed -i "s/YOUR_POSTGRES_PASSWORD/$DATA_E2E_POSTGRES_PASSWORD/g" $DATA_E2E_SCDF_DATAFLOW_PATH/production/deployment-database-patch.yaml
sed -i "s/YOUR_POSTGRES_PASSWORD/$DATA_E2E_POSTGRES_PASSWORD/g" $DATA_E2E_SCDF_SKIPPER_PATH/production/deployment-database-patch.yaml
sed -i "s/YOUR_SCDF_NAMESPACE/$SESSION_NAMESPACE/g" $DATA_E2E_SCDF_DATAFLOW_BASE_PATH/kustomization.yaml
sed -i "s/YOUR_SCDF_NAMESPACE/$SESSION_NAMESPACE/g" $DATA_E2E_SCDF_SKIPPER_BASE_PATH/kustomization.yaml
sed -i "s/YOUR_RABBITMQ_PASSWORD/$DATA_E2E_RABBITMQ_PASSWORD/g" $DATA_E2E_SCDF_SKIPPER_PATH/production/deployment-broker-patch.yaml