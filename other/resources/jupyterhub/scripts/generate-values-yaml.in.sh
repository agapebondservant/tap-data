cat > $1 <<- EOF
namespace: ${DOLLAR}TMP_SESSION_NAMESPACE
image: ${DATA_E2E_REGISTRY_USERNAME}/jupyter-package-repo:${DATA_E2E_JUPYTERHUB_VERSION}
version: ${DATA_E2E_JUPYTERHUB_VERSION}
base_domain: ${DATA_E2E_BASE_URL}
container_repo_user: ${DATA_E2E_REGISTRY_USERNAME}
EOF