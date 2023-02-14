#!/bin/bash

# populate interpolated variables
[ ! -z "$1" ] && ENV_FILE=$1 || ENV_FILE=.env
source "$ENV_FILE"
for orig in `find $(pwd) -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
  grep -qxF $target .gitignore || echo $target >> .gitignore
  git rm --cached -q $target > /dev/null 2>&1
done

# Recreate ConfigMap with environment variables
kubectl delete configmap data-e2e-env || true
sed 's/export //g' .env > .env-properties
kubectl create configmap data-e2e-env --from-env-file=.env-properties
rm .env-properties
