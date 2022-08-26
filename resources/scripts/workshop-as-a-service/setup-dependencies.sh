#!/bin/bash

########################################################################
# Setup Contour
#########################################################################
echo "Installing external Projectcontour Ingress..."
kubectl apply -f https://projectcontour.io/quickstart/v1.18.2/contour.yaml
echo "Projectcontour Ingress installed."
echo "NOTE: Setup a CNAME DNS record for the ProjectContour Loadbalancer endpoint; see https://projectcontour.io/ for more info"

########################################################################
# Setup Metrics Server
#########################################################################
echo "Installing Metrics Server..."
kubectl apply -f resources/metrics-server.yaml
echo "Metrics Server installed."

########################################################################
# Setup Cluster-scoped Cert Manager
#########################################################################
echo "Install Cert manager..."
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
echo "Cert Manager installed."

########################################################################
# Setup self-signed CertManager Issuer, CSR, CA CertManager Issuer
#########################################################################
echo "Installing CertManager Issuers..."
kubectl apply -f resources/cert-manager-issuer.yaml
echo "CertManager Issuers installed."

########################################################################
# Setup sealed secrets
#########################################################################
echo "Installing Sealed Secrets..."
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.4/controller.yaml
echo "SealedSecrets installed."

########################################################################
# Setup Minio endpoint with TLS
#########################################################################
echo "Installing Minio endpoint (with TLS)..."
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio
kubectl create secret generic tls-ssl-minio --from-file=private.key --from-file=public.crt --namespace minio
helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,tls.certSecret=tls-ssl-minio --namespace minio minio minio-legacy/minio
export DATA_E2E_MINIO_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)
export DATA_E2E_MINIO_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)
sed -i '.bak' 's/_DATA_E2E_MINIO_ACCESS_KEY/'"${DATA_E2E_MINIO_ACCESS_KEY}"'/g' .env
sed -i '.bak' 's/_DATA_E2E_MINIO_SECRET_KEY/'"${DATA_E2E_MINIO_SECRET_KEY}"'/g' .env
kubectl apply -f resources/minio-http-proxy.yaml
echo "Minio endpoint with TLS installed."

########################################################################
# Setup Minio endpoint without TLS
#########################################################################
echo "Installing Minio endpoint (no TLS)..."
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio-plain
helm install --set resources.requests.memory=1.5Gi,tls.enabled=false --namespace minio-plain minio minio-legacy/minio --set service.type=LoadBalancer --set service.port=9000
export DATA_E2E_MINIO_PLAIN_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio-plain| base64 --decode)
export DATA_E2E_MINIO_PLAIN_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio-plain| base64 --decode)
sed -i '.bak' 's/_DATA_E2E_MINIO_PLAIN_ACCESS_KEY/'"${DATA_E2E_MINIO_PLAIN_ACCESS_KEY}"'/g' .env
sed -i '.bak' 's/_DATA_E2E_MINIO_PLAIN_SECRET_KEY/'"${DATA_E2E_MINIO_PLAIN_SECRET_KEY}"'/g' .env
sed -i '.bak' 's/_DATA_E2E_MINIO_PLAIN_URL/minio-plain.'"${DATA_E2E_MINIO_URL}"'/g' .env
kubectl apply -f resources/minio-plain-http-proxy.yaml
echo "Minio endpoint (no TLS) installed."

########################################################################
# Setup Prometheus
#########################################################################
echo "Installing Prometheus..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack --create-namespace --namespace=monitoring-tools \
--set prometheus.service.port=8000 --set prometheus.service.type=ClusterIP \
--set grafana.enabled=false,alertmanager.enabled=false,nodeExporter.enabled=false \
--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false\
--wait
kubectl apply -f resources/prometheus-httpproxy.yaml
echo "Prometheus installed."

########################################################################
# Setup Grafana
#########################################################################
echo "Installing Grafana..."
helm install grafana bitnami/grafana --namespace monitoring-tools
export DATA_E2E_GRAFANA_PASSWORD=$(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)
sed -i '.bak' 's/_DATA_E2E_GRAFANA_PASSWORD/'"${DATA_E2E_GRAFANA_PASSWORD}"'/g' .env
kubectl apply -f resources/grafana-httpproxy.yaml
echo "Grafana installed."

########################################################################
# Setup Wavefront Helm Repo
#########################################################################
echo "Installing Wavefront Helm Repo..."
helm repo add wavefront https://wavefronthq.github.io/helm/
helm repo update
echo "Wavefront Helm Repo installed."

########################################################################
# Setup ArgoCD (NOTE: Apply argocd mainfest twice to reconcile missing deps during first run)
#########################################################################
echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f resources/argocd.yaml
kubectl apply -n argocd -f resources/argocd.yaml
echo "ArgoCD installed."
