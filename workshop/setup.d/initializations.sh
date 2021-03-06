#!/bin/bash
#set -eo pipefail
kubectl get configmap data-e2e-env -ndefault -ojson | jq -r ".data | to_entries[] | [.key, .value] | join(\"=\")" | sed 's/^/export /' > ~/.env-properties
. ~/.env-properties
for orig in `find ~ -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
done
