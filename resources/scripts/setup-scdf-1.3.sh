#!/bin/bash

#Install Spring Cloud Data Flow to default namespace
export SCDF_BASE_DATAFLOW_KUSTOMIZE_FL=other/resources/scdf/apps/data-flow/kustomize/base/kustomization.yaml
export SCDF_BASE_SKIPPER_KUSTOMIZE_FL=other/resources/scdf/apps/skipper/kustomize/base/kustomization.yaml
cp ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL} ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}.other
cp ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL} ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}.other
sed -i '' -e "s/namespace/#namespace/g" ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}
sed -i '' -e "s/namespace/#namespace/g" ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}
kubectl create secret docker-registry scdf-image-regcred --namespace=default --docker-server=registry.pivotal.io --docker-username="$DATA_E2E_PIVOTAL_REGISTRY_USERNAME"  --docker-password="$DATA_E2E_PIVOTAL_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f - 
other/resources/scdf/bin/uninstall-dev.sh || true
other/resources/scdf/bin/install-dev.sh # --monitoring prometheus
kubectl apply -f other/resources/scdf/scdf-http-proxy.yaml
cp ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}.other ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}
cp ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}.other ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}
kubectl apply -f other/resources/rabbitmq/rabbitmq-scdf.yaml
kubectl set env deployment/scdf-server \
  SPRING_CLOUD_DATAFLOW_METRICS_DASHBOARD_URL=grafana.$DATA_E2E_BASE_URL \
  LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD=DEBUG \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS=true \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_ENABLED=true \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_HOST=prometheus-proxy \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_PORT=7001
kubectl rollout restart deployment/scdf-server
kubectl set env deployment/skipper \
  SPRING_CLOUD_DATAFLOW_METRICS_DASHBOARD_URL=grafana.$DATA_E2E_BASE_URL \
  LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD=DEBUG \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED=true \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_ENABLED=true \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_HOST=prometheus-proxy \
  MANAGEMENT_METRICS_EXPORT_PROMETHEUS_RSOCKET_PORT=7001
kubectl rollout restart deployment/skipper
