### Deploying Data E2E Workshop (AWS)

- NOTE: eduk8s version used: 20.12.03.1 
(201203.030350.f72ecda)


####Kubernetes Cluster Pre-reqs
- Create new cluster for Educates platform: tkg create cluster data-cluster --plan=devharbor -w 7

- Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain) - storage-class-aws.yml

- Mark the storage class as default: kubectl patch storageclass generic -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

- Create the network policy (network-policy-yml - uses allow-all-ingress for now)

- Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
kube-apiserver --enable-admission-plugins PodSecurityPolicy
kubectl apply -f resources/podsecuritypolicy.yaml

- Install Contour: kubectl apply -f https://projectcontour.io/quickstart/v1.12.0/contour.yaml (NOTE: Change the Loadbalancer's healthcheck from HTTP to TCP in the AWS Console)

- Install Educates Operator: kubectl apply -k https://github.com/eduk8s/eduk8s.git?ref=20.12.03.1

- Verify installation: kubectl get all -n eduk8s

- Specify ingress domain: kubectl set env deployment/eduk8s-operator -n eduk8s INGRESS_DOMAIN=tanzudata.ml

- If using applications with websocket connections, increase idle timeout on ELB in AWS Management Console to 1 hour (default is 30 seconds)

- Deploy cluster-scoped cert-manager:
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.0/cert-manager.yaml
Deploy CERT-MANAGER-ISSUER  (self-signed), CERTIFICATE-SIGNING-REQUEST, CERT-MANAGER-ISSUER (CA): kubectl apply -f resources/cert-manager-issuer.yaml)
    
- Build workshop image:
(see resources/deploy-workshop.sh)

#Only perform the following if there are 7+ nodes in= the k8s cluster
#- Label a subset of the nodes (for which anti-affinity/affinity rules will apply):
#a=0
# for n in $(kubectl get nodes --selector='!node-role.kubernetes.io/master' --output=jsonpath={.items..metadata.name}); do
 #   if [ $a -eq 0 ]; then kubectl label node $n gpdb-worker=master; fi; 
  #  if [ $a -eq 1 ]; then kubectl label node $n gpdb-worker=segment; fi; 
  #  a=$((a+1)) 
#done

- Deploy workshop:
kubectl apply -k .

- Deploy Minio (Server):
(LEGACY APPROACH:)
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio
helm install --set resources.requests.memory=1.5Gi --namespace minio minio minio-legacy/minio
export MINIO_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)
export MINIO_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)
export MINIO_POD_NAME=$(kubectl get pods --namespace minio -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
kubectl expose pod $MINIO_POD_NAME --port=80 --target-port=9000 --name=minio-svc --namespace=minio
kubectl apply -f resources/minio-http-proxy.yaml


(LATEST APPROACH:)
helm repo add minio https://operator.min.io/
helm install --namespace minio-operator --create-namespace --generate-name minio/minio-operator
export MINIO_POD_NAME=$(kubectl get pods --namespace minio-operator -o jsonpath="{.items[0].metadata.name}")
export MINIO_JWT=$(kubectl get secret $(kubectl get serviceaccount console-sa --namespace minio-operator -o jsonpath="{.secrets[0].name}") --namespace minio-operator -o jsonpath="{.data.token}" | base64 --decode)
kubectl expose pod $MINIO_POD_NAME --port=80 --target-port=9090 --name=minio-svc --namespace=minio-operator
kubectl apply -f resources/minio-http-proxy.yaml

- Install Minio Client (on Linux):
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
cp mc /usr/local/bin
mc config host add data-e2e-minio http://minio.tanzudata.ml/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

(on Mac:)
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core fetch --unshallow
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask fetch --unshallow
brew install minio/stable/mc
mc config host add data-e2e-minio http://minio.tanzudata.ml/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

- Add required artifacts to Minio:
(Greenplum-Gemfire connector:)

mc mb -p data-e2e-minio/artifacts
mc cp other/resources/gemfire/gemfire-greenplum-3.4.1.jar data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar
mc policy set download data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar


- Install Prometheus and Grafana:
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
kubectl create ns monitoring-tools
helm install prometheus bitnami/kube-prometheus --namespace monitoring-tools
helm install grafana bitnami/grafana --namespace monitoring-tools
export DATA_E2E_GRAFANA_PASSWORD=$(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)
export GRAFANA_POD_NAME=$(kubectl get pods --namespace monitoring-tools -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
# kubectl expose pod $GRAFANA_POD_NAME --port=80 --target-port=3000 --name=grafana --namespace monitoring-tools
# kubectl apply -f resources/grafana-httpproxy.yaml 
#Configure Prometheus dashboard: https://tanzu.vmware.com/developer/guides/kubernetes/observability-prometheus-grafana-p1/#visualizing-prometheus-data-in-grafana; use http://prometheus-kube-prometheus-prometheus.monitoring-tools.svc.cluster.local:9090 as the Prometheus endpoint

For Prometheus RSocket Proxy:
kubectl apply -f resources/prometheus-proxy/proxyhelm/
kubectl apply -f resources/prometheus-proxy/proxyhelm/prometheus-proxy-http-proxy.yaml

RabbitMQ Dashboard: Dashboard ID 10991

- Pre-deploy Greenplum and Spring Cloud Data Flow:
source .env
resources/setup.sh

- Pre-deeploy Spring Cloud Data Flow:
resources/setup-scdf.sh

- Integrate Wavefront
Wavefront Token: d0bc6a3f-580c-4212-8b35-1c6edd1e4ffb
Wavefront URI: vmware.wavefront.com
Source: 3a4316f6-6501-4750-587b-939e