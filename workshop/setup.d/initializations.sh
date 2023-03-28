#!/bin/bash
#set -eo pipefail
kubectl get configmap data-e2e-env -ndefault -ojson | jq -r ".data | to_entries[] | [.key, .value] | join(\"=\")" | sed 's/^/export /' > ~/.env-properties
. ~/.env-properties
for orig in `find ~ -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
done

# Secret initializations
cd ~ && tanzu init && tanzu plugin install --local bin/cli all
tanzu secret registry delete regsecret --namespace default -y || true
tanzu secret registry add regsecret --username ${DATA_E2E_REGISTRY_USERNAME} \
      --password ${DATA_E2E_REGISTRY_PASSWORD} --server ${DATA_E2E_REGISTRY_USERNAME} \
      --export-to-all-namespaces --yes --namespace default
echo ${DATA_E2E_REGISTRY_PASSWORD} | docker login registry-1.docker.io --username=${DATA_E2E_REGISTRY_USERNAME} --password-stdin

# Git setup
git config --global user.email "edukates-${SESSION_NAMESPACE}@example.com"
git config --global user.name "Edukates-${SESSION_NAMESPACE}"

#RBAC
echo "Setting up RBAC..."
tanzu secret registry delete registry-credentials -n ${SESSION_NAMESPACE} | true
tanzu secret registry add registry-credentials \
--username ${DATA_E2E_REGISTRY_USERNAME} --password ${DATA_E2E_REGISTRY_PASSWORD} \
--server ${DATA_E2E_GIT_SECRETGEN_SERVER} \
--export-to-all-namespaces --yes --namespace ${SESSION_NAMESPACE} | true
kubectl apply -f ~/other/resources/tap/rbac-1.3.yaml -n ${SESSION_NAMESPACE} | true
kubectl apply -f ~/other/resources/tap/rbac.yaml -n ${SESSION_NAMESPACE} | true
kubectl create rolebinding default-admin --clusterrole=admin --serviceaccount=${SESSION_NAMESPACE}:default -n ${SESSION_NAMESPACE}

# Set up git branches
echo "Setting up git branches..."
setupgitbranches()
{
    BRANCHNAME=$1
    git push origin --delete ${BRANCHNAME}-${SESSION_NAMESPACE} | true
    git branch ${BRANCHNAME}-${SESSION_NAMESPACE}; git checkout ${BRANCHNAME}-${SESSION_NAMESPACE}; git add .; git commit -m 'New commit'
    git push origin ${BRANCHNAME}-${SESSION_NAMESPACE}
}

clone_sample_ml_branch()
{
  BRANCHNAME=$1
  git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git -b ${BRANCHNAME} ~/sample-ml-app
  cd ~/sample-ml-app
}

clone_sample_ml_branch main; setupgitbranches main; cd - && rm -rf ~/sample-ml-app
clone_sample_ml_branch gp-main; setupgitbranches gp-main; cd - && rm -rf ~/sample-ml-app
clone_sample_ml_branch kfp-main; setupgitbranches kfp-main; cd - && rm -rf ~/sample-ml-app

git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-kubeflow-pipeline.git ~/sample-kubeflow-pipeline
cd ~/sample-kubeflow-pipeline
setupgitbranches main
setupgitbranches gp-main
setupgitbranches kfp-main
cd - && rm -rf ~/sample-kubeflow-pipeline

git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/mlcode-runner.git ~/mlcode-runner
cd ~/mlcode-runner
setupgitbranches main
cd - && rm -rf ~/mlcode-runner

git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-accelerator.git ~/sample-accelerator
cd ~/sample-accelerator
setupgitbranches main
setupgitbranches gp-main
setupgitbranches kfp-main
cd - && rm -rf ~/sample-accelerator

echo "Git branches set up."

# Accelerators
tanzu acc delete data-catalog-${SESSION_NAMESPACE} -n ${SESSION_NAMESPACE} > /dev/null 2>&1
if [ $? == 0 ]; then echo "Pre-existing accelerators were deleted."; else echo "Accelerators did not exist"; fi

echo "Setting up databases..."
# Database
docker run --rm -it postgres psql ${DATA_E2E_ML_INFERENCE_DB_CONNECT} -c "DROP SCHEMA IF EXISTS \"${SESSION_SCHEMA}\"; CREATE SCHEMA \"${SESSION_DB_SCHEMA}\"" || true
docker run --rm -it postgres psql ${DATA_E2E_ML_TRAINING_DB_CONNECT}-c "DROP SCHEMA IF EXISTS \"${SESSION_SCHEMA}\"; CREATE SCHEMA \"${SESSION_DB_SCHEMA}\"" || true
echo "Databases set up."


