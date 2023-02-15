cat > $1 <<- EOF
namespace: $TMP_SESSION_NAMESPACE
image: oawofolu/jupyter-package-repo:1.0.0
version: 1.0.0
base_domain: tanzumlai.com
container_repo_user: oawofolu
EOF