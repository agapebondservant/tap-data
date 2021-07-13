#!/bin/bash
# Delete pre-existing Greenplum operator and PXF-service
helm uninstall greenplum-operator --namespace greenplum-system
kubectl delete greenplumpxfservice data-e2e-greenplum-pxf --namespace greenplum-system --ignore-not-found=true

# Label Greenplum nodes
ctr=0
for n in $(kubectl get nodes --selector='!node-role.kubernetes.io/master' --output=jsonpath={.items..metadata.name}); do
    kubectl label nodes $n gpdb-worker-
    if [ $ctr -eq 0 ]; then kubectl label nodes $n 'gpdb-worker=master'; echo "Greenplum master label applied for ${n}"; fi; 
    if [ $ctr -eq 1 ]; then kubectl label nodes $n 'gpdb-worker=segment'; echo "Greenplum segment label applied for ${n}"; fi; 
    ctr=$((ctr+1)) 
done

# Install  Greenplum operator

kubectl create ns greenplum-system --dry-run -o yaml | kubectl apply -f - && \
kubectl create secret docker-registry image-pull-secret --namespace=greenplum-system \
--docker-username='${DATA_E2E_REGISTRY_USERNAME}' --docker-password='${DATA_E2E_REGISTRY_PASSWORD}' \
--dry-run -o yaml | kubectl apply -f -
helm install greenplum-operator other/resources/greenplum/operator -f other/resources/greenplum/overrides.yaml -n greenplum-system

