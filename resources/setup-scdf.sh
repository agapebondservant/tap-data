#!/bin/bash
# Delete pre-existing Greenplum operator and PXF-service
kubectl delete greenplumpxfservice data-e2e-greenplum-pxf --namespace greenplum-system --ignore-not-found=true
kubectl delete greenplumcluster gpdb-cluster-data-samples-w01-s001 --ignore-not-found=true --namespace greenplum-system
helm uninstall greenplum-operator --namespace greenplum-system

# Install  Greenplum operator
kubectl create ns greenplum-system --dry-run -o yaml | kubectl apply -f - && \
kubectl create secret docker-registry image-pull-secret --namespace=greenplum-system \
--docker-username='${DATA_E2E_REGISTRY_USERNAME}' --docker-password='${DATA_E2E_REGISTRY_PASSWORD}' \
--dry-run -o yaml | kubectl apply -f -
helm install greenplum-operator other/resources/greenplum/operator -f other/resources/greenplum/overrides.yaml -n greenplum-system

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

