#!/bin/bash

kubectl get configmap data-e2e-env -ndefault -ojson | jq ".data" | sed 's/[{}]//g' > .env-properties
source .env-properties
for orig in `find ~ -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
done
