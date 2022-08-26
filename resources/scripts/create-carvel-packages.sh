source .env

# login to container registry
echo $DOCKER_REG_PASSWORD | docker login registry-1.docker.io --username=$DOCKER_REG_USERNAME --password-stdin

# generate values.yaml file for values-schema
resources/scripts/generate-values-schema-yaml.sh
kubectl create secret generic mlflowappcreds --from-file=resources/mlflow-values-schema.yaml -n tap-install --dry-run=client -o yaml | kubectl apply -f -

#create essential directories
rm -rf package-contents/ && mkdir -p package-contents/config/ && mkdir -p package-contents/.imgpkg
rm -rf package-repo/ && mkdir -p package-repo/.imgpkg package-repo/packages/mlflow.tanzu.vmware.com

# generate package files
cp resources/mlflow-app.yaml package-contents/config/
cp resources/mlflow-values-schema.yaml package-contents/config/
kbld -f package-contents/config/ --imgpkg-lock-output package-contents/.imgpkg/images.yml
imgpkg push -b ${MLFLOW_BASE_REPO}/mlflow-packages:${MLFLOW_VERSION} -f package-contents/

# create package bundle for package repository
ytt -f resources/mlflow-values-schema.yaml --data-values-schema-inspect -o openapi-v3 > resources/schema-openapi.yaml
ytt -f resources/mlflow-package-template.yaml  --data-value-file openapi=resources/schema-openapi.yaml -v version="${MLFLOW_VERSION}" > package-repo/packages/mlflow.tanzu.vmware.com/${MLFLOW_VERSION}.yaml
cp resources/mlflow-package-metadata.yaml package-repo/packages/mlflow.tanzu.vmware.com
kbld -f package-repo/packages/ --imgpkg-lock-output package-repo/.imgpkg/images.yml
imgpkg push -b ${MLFLOW_BASE_REPO}/mlflow-packages-repo:${MLFLOW_VERSION} -f package-repo/

# deploy Postgres cluster
kubectl wait --for=condition=Ready pod -l app=postgres-operator --timeout=120s
kubectl apply -f resources/postgres/postgres-tap-cluster.yaml