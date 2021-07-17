
#!/bin/bash

# Set variables
export DATA_E2E_POSTGRES_HOSTNAME=$(kubectl get svc pginstance-1 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' -n $SESSION_NAMESPACE)
export DATA_E2E_POSTGRES_DB=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.dbname}' -n $SESSION_NAMESPACE | base64 -D)
export DATA_E2E_POSTGRES_USERNAME=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.username}' -n $SESSION_NAMESPACE | base64 -D) 
export DATA_E2E_POSTGRES_PASSWORD=$(kubectl get secrets pginstance-1-db-secret -o jsonpath='{.data.password}' -n $SESSION_NAMESPACE | base64 -D)

export DATA_E2E_RABBITMQ_HOSTNAME=$(kubectl get svc rabbitcluster1 -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"  -n $SESSION_NAMESPACE)
export DATA_E2E_RABBITMQ_PORT=$(kubectl get svc rabbitcluster1 -o jsonpath="{.status.loadBalancer.ingress[0].port}"  -n $SESSION_NAMESPACE)
export DATA_E2E_RABBITMQ_USERNAME=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.username}"  -n $SESSION_NAMESPACE | base64 --decode)
export DATA_E2E_RABBITMQ_PASSWORD=$(kubectl get secret rabbitcluster1-default-user -o jsonpath="{.data.password}"  -n $SESSION_NAMESPACE | base64 --decode)

export DATA_E2E_SCDF_DATAFLOW_PATH=other/resources/scdf/spring-cloud-data-flow/apps/data-flow/kustomize/overlays/dev
export DATA_E2E_SCDF_SKIPPER_PATH=other/resources/scdf/spring-cloud-data-flow/apps/skipper/kustomize/overlays/dev 

for file in $DATA_E2E_SCDF_DATAFLOW_PATH/deployment-postgresql-patch.yaml \
            $DATA_E2E_SCDF_DATAFLOW_PATH/kustomization.yaml \
            $DATA_E2E_SCDF_SKIPPER_PATH/deployment-rabbitmq-patch.yaml \
            $DATA_E2E_SCDF_SKIPPER_PATH/deployment-postgresql-patch.yaml \
            $DATA_E2E_SCDF_SKIPPER_PATH/kustomization.yaml do 
    sed -i "s/YOUR_POSTGRES_PASSWORD/$DATA_E2E_POSTGRES_PASSWORD" $file
    sed -i "s/YOUR_SCDF_NAMESPACE/$SESSION_NAMESPACE" $file
    sed -1 "s/YOUR_RABBITMQ_PASSWORD/$DATA_E2E_RABBITMQ_PASSWORD" $file
done