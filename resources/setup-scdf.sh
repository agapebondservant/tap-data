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
other/resources/scdf/bin/install-dev.sh #--monitoring prometheus
kubectl apply -f other/resources/scdf/scdf-http-proxy-default.yaml
cp ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}.other ${SCDF_BASE_DATAFLOW_KUSTOMIZE_FL}
cp ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}.other ${SCDF_BASE_SKIPPER_KUSTOMIZE_FL}

