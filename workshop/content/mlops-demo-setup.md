### Rapid-fire Demo

#### Before you begin
Run the following prep script:
```execute
tanzu package repository add jupyterhub-package-repository --url {{DATA_E2E_REGISTRY_USERNAME}}/jupyter-package-repo:{{DATA_E2E_JUPYTERHUB_VERSION}} -n {{session_namespace}};
cat > ~/other/resources/jupyterhub/jupyter-values.yaml <<- EOF
namespace: {{ session_namespace }}
image: {{DATA_E2E_REGISTRY_USERNAME}}/jupyter-package-repo:{{DATA_E2E_JUPYTERHUB_VERSION}}
version: {{DATA_E2E_JUPYTERHUB_VERSION}}
base_domain: {{DATA_E2E_BASE_URL}}
container_repo_user: {{DATA_E2E_REGISTRY_USERNAME}}
EOF
```








