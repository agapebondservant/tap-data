#!/bin/bash
#set -eo pipefail
kubectl get configmap data-e2e-env -ndefault -ojson | jq -r ".data | to_entries[] | [.key, .value] | join(\"=\")" | sed 's/^/export /' > ~/.env-properties
. ~/.env-properties
for orig in `find ~ -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
done

cd ~ && tanzu init && tanzu plugin install --local bin/cli secret
tanzu secret registry delete regsecret --namespace default -y || true
tanzu secret registry add regsecret --username ${DATA_E2E_REGISTRY_USERNAME} \
      --password ${DATA_E2E_REGISTRY_PASSWORD} --server ${DATA_E2E_REGISTRY_USERNAME} \
      --export-to-all-namespaces --yes --namespace default
echo ${DATA_E2E_REGISTRY_PASSWORD} | docker login registry-1.docker.io --username=${DATA_E2E_REGISTRY_USERNAME} --password-stdin
