# Install tanzu plugins
tanzu plugin repo update -b tanzu-cli-framework core

tanzu plugin install secret

# Deploy secrets
tanzu secret registry delete scdf-reg-creds-dockerhub --namespace default -y || true
tanzu secret registry add scdf-reg-creds-dockerhub \
  --namespace default \
  --export-to-all-namespaces \
  --server https://index.docker.io/v1/ \
  --username $DATA_E2E_REGISTRY_USERNAME \
  --password $DATA_E2E_REGISTRY_PASSWORD \
  --yes

# Export TanzuNet access credentials
tanzu secret registry delete scdf-reg-creds-dev-registry --namespace default -y || true

tanzu secret registry add scdf-reg-creds-dev-registry \
  --username $DATA_E2E_PIVOTAL_REGISTRY_USERNAME \
  --password $DATA_E2E_PIVOTAL_REGISTRY_PASSWORD \
  --server dev.registry.pivotal.io \
  --namespace default \
  --export-to-all-namespaces \
  --yes

# Deploy the PackageRepository
tanzu package repository add scdf-pro-repo \
  --url dev.registry.pivotal.io/p-scdf-for-kubernetes/scdf-pro-repo:1.5.0-SNAPSHOT

# Deploy the Package
tanzu package install scdf-pro-demo \
  --package-name scdfpro.tanzu.vmware.com \
  --version 1.5.0-SNAPSHOT

