#!/bin/bash
#set -eo pipefail
kubectl get configmap data-e2e-env -ndefault -ojson | jq -r ".data | to_entries[] | [.key, .value] | join(\"=\")" | sed 's/^/export /' > ~/.env-properties
. ~/.env-properties
for orig in `find ~ -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
done

# Secret initializations
cd ~ && tanzu init && tanzu plugin install --local bin/cli secret
tanzu secret registry delete regsecret --namespace default -y || true
tanzu secret registry add regsecret --username ${DATA_E2E_REGISTRY_USERNAME} \
      --password ${DATA_E2E_REGISTRY_PASSWORD} --server ${DATA_E2E_REGISTRY_USERNAME} \
      --export-to-all-namespaces --yes --namespace default
echo ${DATA_E2E_REGISTRY_PASSWORD} | docker login registry-1.docker.io --username=${DATA_E2E_REGISTRY_USERNAME} --password-stdin

# Git setup
git config --global user.email "edukates-${SESSION_NAMESPACE}@example.com"
git config --global user.name "Edukates-${SESSION_NAMESPACE}"

git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git ~/sample-ml-app
cd ~/sample-ml-app
for i in ( 'main', 'api-main', 'kfp-main' )
do
  git push origin --delete $i-${SESSION_NAMESPACE} | true
  git branch $i-${SESSION_NAMESPACE}; git checkout $i-${SESSION_NAMESPACE}; git add .; git commit -m 'New commit'
  git push origin $i-${SESSION_NAMESPACE}
done
cd - && rm -rf ~/sample-ml-app

git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/mlcode-runner.git ~/mlcode-runner
cd ~/mlcode-runner
git push origin --delete main-${SESSION_NAMESPACE} | true
git branch main-${SESSION_NAMESPACE}; git checkout main-${SESSION_NAMESPACE}; git add .; git commit -m 'New commit'
git push origin main-${SESSION_NAMESPACE}
cd - && rm -rf ~/mlcode-runner



