# Install tanzu plugins
tanzu plugin repo update -b tanzu-cli-framework core

tanzu plugin install secret

# Deploy the PackageRepository
tanzu package repository add scdf-pro-repo \
  --url dev.registry.pivotal.io/p-scdf-for-kubernetes/scdf-pro-repo:1.5.0-SNAPSHOT

# Deploy the Package
tanzu package install scdf-pro-demo \
  --package-name scdfpro.tanzu.vmware.com \
  --version 1.5.0-SNAPSHOT \
  --values-file resources/scdf-pro/values.yaml

