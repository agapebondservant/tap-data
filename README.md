### Deploying Data E2E Workshop (tested on TKG on AWS)

NOTE:
* Currently requires **cluster-admin** privileges to set up.
* Currently sets up the Learning Center's user with **cluster-admin** privileges. For this reason,
  it is recommended not to use a permanent Kubernetes cluster, and instead to use a
  temporary Kubernetes cluster that is created on demand and destroyed right after a session (see [here](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-learning-center-about.html#use-cases-1 "Docs"))

#### Contents
1. [Kubernetes Cluster Prep](#pre-reqs)
2. [Install Minio](#minio)
3. [Install Prometheus and Grafana](#prometheusgrafana)
4. [Install Wavefront](#wavefront)
5. [Install Datadog](#datadog)
6. [Install ArgoCD](#argocd)
7. [Install OperatorUI](#operatorui)
8. [Pre-deploy Greenplum and Spring Cloud Data Flow](#predeploys)
9. [Build secondary cluster (for multi-site demo)](#multisite)
10. [Install TAP](#tap-install)
11. [Deploy Tanzu Data Workshops](#buildanddeploy)
12. [Deploy Single Workshop to Pre-Existing LearningCenter Portal](#buildsingle)
13. [Other: How-tos/General Info (not needed for setup)](#other)

#### Kubernetes Cluster Prep<a name="pre-reqs"/>
* Create .env file in root directory (use .env-sample as a template - do NOT check into Git)

* Populate the .env file where possible (NOTE: only a subset of the variables can be populated at the moment.
New entries will be populated as the install proceeds)

* Populate a ConfigMap based on the .env file
```
sed 's/export //g' .env > .env-properties && kubectl create configmap data-e2e-env --from-env-file=.env-properties && rm .env-properties
```

* Create a Management Cluster (Optional - required only if management cluster does not exist) 
```
tanzu management-cluster permissions aws set && tanzu management-cluster create <your-management-cluster-name>  --file  -v 6
```
(NOTE: Follow instructions for deploying a Tanzu Management cluster here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-index.html)

* Create new cluster for Educates platform: 
```
tanzu login 
tanzu cluster create <your-cluster-name> --file resources/tanzu-aws.yaml
watch tanzu cluster get <your-cluster-name>
tanzu cluster kubeconfig get <your-cluster-name> --admin
kubectl config use-context <your-cluster-name>-admin@<your-cluster-name>
```

* Update manifests as appropriate:
```
source .env
for orig in `find . -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
  grep -qxF $target .gitignore || echo $target >> .gitignore
done
```

* Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain) 
```
kubectl apply -f resources/storageclass.yaml
```

* Mark the storage class as default: 
```
kubectl patch storageclass generic -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

* Create the network policy (networkpolicy.yaml - uses allow-all-ingress for now)
```
kubectl apply -f resources/networkpolicy.yaml
```

* Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
```
kubectl apply -f resources/podsecuritypolicy.yaml
```

* Install Contour: (NOTE: Change the Loadbalancer's healthcheck from HTTP to TCP in the AWS Console)
```
kubectl apply -f https://projectcontour.io/quickstart/v1.18.2/contour.yaml 
```

* Install the Kubernetes Metrics server: 
```
kubectl apply -f resources/metrics-server.yaml; watch kubectl get deployment metrics-server -n kube-system
```

* Deploy cluster-scoped cert-manager:
```
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
```

* Deploy CERT-MANAGER-ISSUER  (self-signed), CERTIFICATE-SIGNING-REQUEST, CERT-MANAGER-ISSUER (CA):
```
kubectl apply -f resources/cert-manager-issuer.yaml
```

* Install SealedSecrets:
```
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.4/controller.yaml
```

* Install Istio: (used by Multi-site workshops, Gemfire workshops)
```
other/resources/bin/istioctl install --set profile=demo -y; 
#kubectl label pods istio-injection=enabled --selector=<your selector> --namespace=<your namespace>;
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}');
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}');
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}');
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
```

* If using applications with WebSocket connections, increase idle timeout on ELB in AWS Management Console to 1 hour (default is 30 seconds)

#### Install Minio<a name="minio"/>
* Deploy Minio (Server) with TLS:

Setup TLS cert for Minio:
```
#openssl genrsa -out tls.key 2048
openssl genrsa -out private.key 2048
#openssl req -new -x509 -nodes -days 730 -key tls.key -out tls.crt -config other/resources/minio/openssl.conf
openssl req -new -x509 -nodes -days 730 -key private.key -out public.crt -config other/resources/minio/openssl.conf
```

(LEGACY APPROACH: used by this workshop)
```
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio
#kubectl create secret generic tls-ssl-minio --from-file=tls.key --from-file=tls.crt --namespace minio
kubectl create secret generic tls-ssl-minio --from-file=private.key --from-file=public.crt --namespace minio
helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,tls.certSecret=tls-ssl-minio --namespace minio minio minio-legacy/minio
#helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,tls.publicCrt=tls.crt,tls.privateKey=tls.key,tls.certSecret=tls-ssl-minio --namespace minio minio minio-legacy/minio
export MINIO_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)
export MINIO_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)
export MINIO_POD_NAME=$(kubectl get pods --namespace minio -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
source .env
export MINIO_SERVER_URL=$DATA_E2E_MINIO_URL
kubectl apply -f resources/minio-http-proxy.yaml
```

(TROUBLESHOOTING RECOMMENDED APPROACH: NOT used by this workshop)
```
kubectl create namespace minio-operator || true
kubectl apply -f resources/minio-tls-cert.yaml -n minio-operator
helm repo add minio-operator https://charts.min.io/
helm repo update

until kubectl get secret minio-tls -n minio-operator; \
do \
@echo "Waiting for minio-tls secret..."; \
sleep 1; \
done

helm upgrade minio-operator minio-operator/minio \
--install \
--create-namespace \
--namespace minio-operator \
--set replicas=1 \
--set mode=standalone \
--set resources.requests.memory=256Mi \
--set persistence.size=1Gi \
--set persistence.storageClass=generic \
--set service.type=ClusterIP \
--set consoleService.type=ClusterIP \
--set rootUser=admin \
--set rootPassword=adminsecret \
--set buckets[0].name=pg-backups,buckets[0].policy=public,buckets[0].purge=false \
--set tls.enabled=true \
--set tls.certSecret=minio-tls \
--set tls.publicCrt=tls.crt \
--set tls.privateKey=tls.key \
--set DeploymentUpdate.type=Recreate \
-f resources/minio-values.yaml

kubectl rollout status -n minio-operator deployment.apps/minio

export MINIO_POD_NAME=$(kubectl get pods --namespace minio-operator -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
export MINIO_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.rootUser}" -n minio-operator| base64 --decode)
export MINIO_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.rootPassword}" -n minio-operator| base64 --decode)

kubectl apply -f resources/minio-operator-http-proxy.yaml
```

(NEXTGEN APPROACH: NOT used by this workshop)
```
helm repo add minio https://operator.min.io/
helm install --namespace minio-operator --create-namespace --generate-name minio/minio-operator
export MINIO_POD_NAME=$(kubectl get pods --namespace minio-operator -o jsonpath="{.items[0].metadata.name}")
export MINIO_JWT=$(kubectl get secret $(kubectl get serviceaccount console-sa --namespace minio-operator -o jsonpath="{.secrets[0].name}") --namespace minio-operator -o jsonpath="{.data.token}" | base64 --decode)
kubectl expose pod $MINIO_POD_NAME --port=80 --target-port=9090 --name=minio-svc --namespace=minio-operator
kubectl apply -f resources/minio-http-proxy.yaml
```

Note: How to install Minio Client (not used by this workshop):
on Linux:
```
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
cp mc /usr/local/bin
mc config host add tanzu-data-tap-minio http://${DATA_E2E_MINIO_URL}/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
```
on Mac:
```
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core fetch --unshallow
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask fetch --unshallow
brew install minio/stable/mc
mc config host add tanzu-data-tap-minio http://${DATA_E2E_MINIO_URL}/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
```

Deploy a second Minio Chart without TLS:
```
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio-plain
helm install --set resources.requests.memory=1.5Gi,tls.enabled=false --namespace minio-plain minio minio-legacy/minio --set service.type=LoadBalancer --set service.port=9000
export MINIO_PLAIN_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio-plain| base64 --decode)
export MINIO_PLAIN_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio-plain| base64 --decode)
export MINIO_PLAIN_POD_NAME=$(kubectl get pods --namespace minio-plain -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
export MINIO_PLAIN_SERVER_URL=${DATA_E2E_MINIO_PLAIN_URL}
```

Add required artifacts to Minio (Greenplum-Gemfire connector):
```
mc mb -p data-e2e-minio/artifacts
mc cp other/resources/gemfire/gemfire-greenplum-3.4.1.jar data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar
mc policy set download data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar
```

#### Install Prometheus and Grafana <a name="prometheusgrafana"/>
* Install Prometheus and Grafana:
Prometheus:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
#kubectl create ns monitoring-tools
#helm install prometheus bitnami/kube-prometheus --namespace monitoring-tools
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack --create-namespace --namespace=monitoring-tools \
--set prometheus.service.port=8000 --set prometheus.service.type=ClusterIP \
--set grafana.enabled=false,alertmanager.enabled=false,nodeExporter.enabled=false \
--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false\
--wait
kubectl apply -f resources/prometheus-httpproxy.yaml
```

Grafana:
```
helm install grafana bitnami/grafana --namespace monitoring-tools
export DATA_E2E_GRAFANA_PASSWORD=$(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)
export GRAFANA_POD_NAME=$(kubectl get pods --namespace monitoring-tools -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
# kubectl expose pod $GRAFANA_POD_NAME --port=80 --target-port=3000 --name=grafana --namespace monitoring-tools
kubectl apply -f resources/grafana-httpproxy.yaml 
```

Configure Prometheus dashboard: https://tanzu.vmware.com/developer/guides/kubernetes/observability-prometheus-grafana-p1/#visualizing-prometheus-data-in-grafana; use http://prometheus-kube-prometheus-prometheus.monitoring-tools.svc.cluster.local:9090 as the Prometheus endpoint

For Prometheus RSocket Proxy:
```
kubectl apply -f resources/prometheus-proxy/proxyhelm/
kubectl apply -f resources/prometheus-proxy/proxyhelm/prometheus-proxy-http-proxy.yaml
```

#### Install Wavefront <a name="wavefront"/>
```
source </path/to/env/file>
helm repo add wavefront https://wavefronthq.github.io/helm/
helm repo update
```


#### Install Datadog <a name="datadog"/>
* Install Datadog: (only required for these workshops: <b>Postgres Deep Dive</b>)
```
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog -f other/resources/datadog/data-dog.yaml \
- --set datadog.site='datadoghq.com' --set datadog.apiKey='${DATA_E2E_DATADOG_API_KEY}' datadog/datadog
```
  
#### Install ArgoCD <a name="argocd"/>
* Install ArgoCD:
```
kubectl create namespace argocd
kubectl apply -n argocd -f resources/argocd.yaml
```

#### Install Operator UI <a name="operatorui"/>
* Install Operator UI: (must have pre-installed Tanzu Data operators)
```
kubectl create namespace operator-ui
kubectl create configmap kconfig --from-file </path/to/multicluster/kubeconfig> --namespace operator-ui
other/resources/operator-ui/annotate.sh
kubectl apply -f other/resources/operator-ui/overlays.yaml
kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-app.yaml --namespace operator-ui
kubectl annotate pkgi <RABBITMQ_PKGI_NAME> ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=rabbitmq-operator-tsqlui-annotation-overlay-secret -n<RABBITMQ_PKGI_NAMESPACE> --overwrite
kubectl annotate pkgi <POSTGRES_PKGI_NAME> ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=postgres-operator-tsqlui-annotation-overlay-secret -n<POSTGRES_PKGI_NAMESPACE> --overwrite
kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-httpproxy.yaml --namespace operator-ui #only if using ProjectContour for Ingress
kubectl get all -noperator-ui
```

#### Pre-deploy Greenplum and Spring Cloud Data Flow<a name="predeploys"/>
* Pre-deploy Greenplum: (only required for these workshops: <b>Greenplum Workshops</b>)
```
source .env
resources/scripts/setup.sh
```
* Pre-deploy Spring Cloud Data Flow: (only required for these workshops: <b>RabbitMQ Workshops, Gemfire Workshops, Greenplum Workshops, ML/AI workshops</b>)
```
resources/scripts/setup-scdf.sh
```
Register gemfire starter apps:
sink.gemfire=docker:springcloudstream/gemfire-sink-rabbit:2.1.6.RELEASE
source.gemfire=docker:springcloudstream/gemfire-source-rabbit:2.1.6.RELEASE
source.gemfire-cq=docker:springcloudstream/gemfire-cq-source-rabbit:2.1.6.RELEASE

#### Build secondary cluster (only required for multi-site demo)<a name="multisite"/>
* Create new cluster:
```
tanzu cluster create tanzu-data-tap-secondary --file resources/tanzu-aws-secondary.yaml
tanzu cluster kubeconfig get tanzu-data-tap-secondary --admin
```
** NOTE: The following instructions should be applied to the new cluster created above.**
* Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain):
```    
kubectl apply -f resources/storageclass.yaml
kubectl patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

* Create the network policy 
```
kubectl apply -f resources/networkpolicy.yaml
```

* Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
```    
kubectl apply -f resources/podsecuritypolicy.yaml
```

* Install Contour: (NOTE: Change the Loadbalancer's healthcheck from HTTP to TCP in the AWS Console)
```
kubectl apply -f https://projectcontour.io/quickstart/v1.18.2/contour.yaml
```

* Install the Kubernetes Metrics server: 
```
kubectl apply -f resources/metrics-server.yaml; watch kubectl get deployment metrics-server -n kube-system
```
  
* Install cert-manager:
```
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
kubectl apply -f resources/cert-manager-issuer.yaml
```
  
* Install Gemfire operator:
```
  source .env
  kubectl create ns gemfire-system --dry-run -o yaml | kubectl apply -f -
  kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username="$DATA_E2E_PIVOTAL_REGISTRY_USERNAME" --docker-password="$DATA_E2E_PIVOTAL_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -
  helm uninstall  gemfire --namespace gemfire-system; helm install gemfire other/resources/gemfire/gemfire-operator-1.0.3/ --namespace gemfire-system
```

* Install Gemfire cluster:
```
kubectl create secret docker-registry app-image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username="$DATA_E2E_REGISTRY_USERNAME" --docker-password="$DATA_E2E_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -
kubectl apply -f other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml -n gemfire-system
```   
* Install Istio:
(In primary cluster)
```
other/resources/istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=other/resources/istio-1.13.2/manifests -y
```
(In secondary cluster)
```
other/resources/istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=other/resources/istio-1.13.2/manifests -y
```
  
* Generate kubeconfig for accessing secondary cluster: (Must install kubeseal: https://github.com/bitnami-labs/sealed-secrets)
(On secondary cluster:)
```
t_secret=$(kubectl get sa default -o jsonpath={.secrets[0].name})
t_ca_crt_data=$(kubectl get secret ${t_secret} -o jsonpath="{.data.ca\.crt}" | openssl enc -d -base64 -A)
t_token=$(kubectl get secret ${t_secret} -o jsonpath="{.data.token}" | openssl enc -d -base64 -A)
t_context=$(kubectl config current-context)
t_cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$t_context\")].context.cluster}")
t_server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$t_cluster\")].cluster.server}")
t_user=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$t_context\")].context.user}")
t_client_certificate_data=$(kubectl config view --flatten -o jsonpath="{.users[?(@.name==\"$t_user\")].user.client-certificate-data}" | openssl enc -d -base64 -A)
t_client_key_data=$(kubectl config view --flatten -o jsonpath="{.users[?(@.name==\"$t_user\")].user.client-key-data}" | openssl enc -d -base64 -A)
t_ca_crt="$(mktemp)"; echo "$t_ca_crt_data" > $t_ca_crt
t_client_key="$(mktemp)"; echo "$t_client_key_data" > $t_client_key
t_client_certificate="$(mktemp)"; echo "$t_client_certificate_data" > $t_client_certificate
 
kubectl config set-credentials secondary-user --client-certificate="$t_client_certificate" --client-key="$t_client_key" --embed-certs=true --kubeconfig myfile
kubectl config set-cluster secondary-cluster --server="$t_server" --certificate-authority="$t_ca_crt" --embed-certs=true --kubeconfig myfile
kubectl config set-context secondary-ctx --cluster="secondary-cluster" --user="secondary-user" --kubeconfig myfile

kubectl create secret generic kconfig --from-file=myfile --dry-run=client -o yaml > kconfigsecret.yaml
kubeseal --scope cluster-wide -o yaml <kconfigsecret.yaml> resources/kconfigsealedsecret.yaml
```

(On primary cluster:)
```
kubectl apply -f resources/kconfigsealedsecret.yaml
```

### Install TAP<a name="tap-install"/>
(NOTE: TAP pre-reqs: https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-intro.html)

#### Install TAP command line tooling
```
mkdir $HOME/tanzu
export TANZU_CLI_NO_INIT=true
cd $HOME/tanzu
sudo install cli/core/0.11.1/tanzu-core-linux_amd64 /usr/local/bin/tanzu
tanzu plugin install --local cli all
tanzu plugin list
```
##### Install imgpkg
```
wget -O- https://carvel.dev/install.sh > install.sh
sudo bash install.sh
imgpkg version
```
#### Relocate images to local registry
```
source .env
docker login registry-1.docker.io
docker login registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$DATA_E2E_REGISTRY_USERNAME
export INSTALL_REGISTRY_PASSWORD=$DATA_E2E_REGISTRY_PASSWORD
#export TAP_VERSION=1.1.0
export TAP_VERSION=1.1.1
export INSTALL_REGISTRY_HOSTNAME=index.docker.io
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tap-packages
imgpkg copy -b registry.tanzu.vmware.com/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:${DATA_E2E_RABBIT_OPERATOR_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/oawofolu/vmware-tanzu-rabbitmq

kubectl create ns tap-install
tanzu secret registry add tap-registry \
--username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
--server ${INSTALL_REGISTRY_HOSTNAME} \
--export-to-all-namespaces --yes --namespace tap-install
tanzu package repository add tanzu-tap-repository \
--url ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tap-packages:$TAP_VERSION \
--namespace tap-install
tanzu package repository get tanzu-tap-repository --namespace tap-install
tanzu package available list --namespace tap-install
tanzu package available list tap.tanzu.vmware.com --namespace tap-install
tanzu package available get tap.tanzu.vmware.com/$TAP_VERSION --values-schema --namespace tap-install
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values.yaml -n tap-install
```

To upgrade to TAP 1.1.1:
```
tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.1.1-build.1  --values-file resources/tap-values.yaml -n tap-install
tanzu package repository get tanzu-tap-repository --namespace tap-install
```

To check on a package's install status:
```
tanzu package installed get tap<or name pf package> -n tap-install
```

To check that all expected packages were installed successfully:
```
tanzu package installed list -A -n tap-install
```

* Install Learning Center:
```
tanzu package available list learningcenter.tanzu.vmware.com --namespace tap-install # To view available packages for learningcenter
tanzu package install learning-center --package-name learningcenter.tanzu.vmware.com --version 0.1.1 -f resources/learning-center-config.yaml -n tap-install
kubectl get all -n learningcenter
tanzu package available list workshops.learningcenter.tanzu.vmware.com --namespace tap-install
```

* (Optional) Deploy the sample Learning Center Workshop:
```
kubectl apply -f resources/workshop-sample.yaml
kubectl apply -f resources/training-portal-sample.yaml
watch kubectl get learningcenter-training
```

* Install FluxCD controller:
```
tanzu package available list fluxcd.source.controller.tanzu.vmware.com -n tap-install (ensure packages are listed)
tanzu package install fluxcd-source-controller -p fluxcd.source.controller.tanzu.vmware.com -v 0.16.4 -n tap-install
Verify that package is running: tanzu package installed get fluxcd-source-controller -n tap-install
Verify "Reconcile Succeeded": kubectl get pods -n flux-system
```
* Install Source Controller:
```
tanzu package available list controller.source.apps.tanzu.vmware.com --namespace tap-install
tanzu package install source-controller -p controller.source.apps.tanzu.vmware.com -v 0.2.0 -n tap-install
Verify that package is running: tanzu package installed get source-controller -n tap-install
```
* Install App Accelerator: (see https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-cert-mgr-contour-fcd-install-cert-mgr.html)
```
tanzu package available list accelerator.apps.tanzu.vmware.com --namespace tap-install
tanzu package install app-accelerator -p accelerator.apps.tanzu.vmware.com -v 1.0.1 -n tap-install -f resources/app-accelerator-values.yaml
Verify that package is running: tanzu package installed get app-accelerator -n tap-install
Get the IP address for the App Accelerator API: kubectl get service -n accelerator-system
```

* Install the TAP GUI:
```
tanzu package available list tap-gui.tanzu.vmware.com --namespace tap-install
source .env
envsubst < resources/tap-gui-values.in.yaml > resources/tap-gui-values.yaml
tanzu package install tap-gui \
  --package-name tap-gui.tanzu.vmware.com \
  --version 1.1.0 -n tap-install \
  -f resources/tap-gui-values.yaml
```

Verify installation:
```
tanzu package installed get tap-gui -n tap-install
```

Publish Accelerators:
```
tanzu plugin install --local <path-to-tanzu-cli> all
tanzu acc create mlflow --git-repository https://github.com/agapebondservant/mlflow-accelerator.git --git-branch main
```

#### Deploy Tanzu Data Workshops<a name="buildanddeploy"/>
* Build Workshop image:
  (see resources/scripts/deploy-image.sh)

[comment]: <> (Only perform the following if there are 7+ nodes in= the k8s cluster)
[comment]: <> (Label a subset of the nodes \(for which anti-affinity/affinity rules will apply\):)
[comment]: <> (a=0)
[comment]: <> (for n in $\(kubectl get nodes --selector='!node-role.kubernetes.io/master' --output=jsonpath={.items..metadata.name}\); do)
[comment]: <> (  if [ $a -eq 0 ]; then kubectl label node $n gpdb-worker=master; fi; )
[comment]: <> (  if [ $a -eq 1 ]; then kubectl label node $n gpdb-worker=segment; fi; )
[comment]: <> (  a=$\(\(a+1\)\) )
[comment]: <> (done)

* Build Workshop image and deploy workshop to Kubernetes cluster:
```
resources/scripts/deploy-workshop.sh
```

#### Deploy Single Workshop to Pre-Existing LearningCenter Portal<a name="buildsingle"/>
* Make sure all relevant pre-requisites are set up in your cluster: <a href="#pre-reqs">Setup required pre-installations</a>
* Make sure TAP is installed (including LearningCenter): <a href="#tap-install">Setup required pre-installations</a>
* Make sure additional pre-requisites are set up for the workshop: <a href="#workshop-pre-reqs">Setup required pre-installations for workshop</a>
 Follow the instructions to add the desired workshop to your Learning Center as shown:

  | Workshop Name                              | Link                                                       |
  |--------------------------------------------|------------------------------------------------------------|
  | Tanzu Data with TAP                        | <a href="#workshopa">View Instructions</a>                 |
  | Tanzu Postgres - Kubernetes Deepdive       | <a href="#workshopb">View Instructions</a>                 |
  | Tanzu RabbitMQ - Commercial Features       | <a href="#workshopc">View Instructions</a>                 |

##### Deploy "Tanzu Data With TAP"<a name="workshop-pre-reqs"/>
Setup pre-reqs for various packages required by workshops with Tanzu cli:
```
source <path-to-your-env-file>
echo $DATA_E2E_REGISTRY_PASSWORD | docker login registry-1.docker.io --username=$DATA_E2E_REGISTRY_USERNAME --password-stdin
echo $DATA_E2E_PIVOTAL_REGISTRY_PASSWORD | docker login registry.tanzu.vmware.com --username=$DATA_E2E_PIVOTAL_REGISTRY_USERNAME --password-stdin
export TDS_VERSION=1.0.0
imgpkg copy -b registry.tanzu.vmware.com/packages-for-vmware-tanzu-data-services/tds-packages:$TDS_VERSION --to-repo $DATA_E2E_REGISTRY_USERNAME/tds-packages
```

##### Deploy "Tanzu Data With TAP"<a name="workshopa"/>
Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-with-tap
    capacity: 10 #Change the capacity to the number of expected participants
    reserved: 1
    expires: 120m
    orphaned: 5m
```

Run the following:
```
resources/scripts/deploy-handson-workshop.sh <path-to-your-env-file>
kubectl delete --all learningcenter-training
kubectl apply -f resources/hands-on/system-profile.yaml
kubectl apply -f resources/hands-on/workshop-data-with-tap-external.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
(For Presenter Mode:)
kubectl apply -f resources/hands-on/workshop-data-with-tap-demo.yaml
watch kubectl get learningcenter-training
```

##### Deploy "Tanzu Postgres - Kubernetes Deepdive"<a name="workshopb"/>
Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-postgres-deepdive
  capacity: 10 #Change the capacity to the number of expected participants
  reserved: 1
  expires: 120m
  orphaned: 5m
- name: data-postgres-deepdive-demo
  capacity: 1
  expires: 120m
  orphaned: 5m
```

Run the following:
```
resources/scripts/deploy-handson-workshop.sh <path-to-your-env-file>
kubectl delete --all learningcenter-training
kubectl apply -f resources/hands-on/system-profile.yaml
kubectl apply -f resources/hands-on/workshop-postgres-deepdive.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
(For Presenter Mode:)
kubectl apply -f resources/hands-on/workshop-postgres-deepdive-demo.yaml
watch kubectl get learningcenter-training
```

##### Deploy "Tanzu RabbitMQ - Commercial Features"<a name="workshopc"/>
Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-rabbitmq-commercial-features
  capacity: 10 #Change the capacity to the number of expected participants
  reserved: 1
  expires: 120m
  orphaned: 5m
- name: data-rabbitmq-commercial-features-demo
  capacity: 1
  expires: 120m
  orphaned: 5m
```

Run the following:
```
resources/scripts/deploy-handson-workshop.sh <path-to-your-env-file>
kubectl delete --all learningcenter-training
kubectl apply -f resources/hands-on/system-profile.yaml
kubectl apply -f resources/hands-on/workshop-rabbitmq-commercial-features.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
(For Presenter Mode:)
kubectl apply -f resources/hands-on/workshop-rabbitmq-commercial-features-demo.yaml
watch kubectl get learningcenter-training
```
  
#### Other: How-tos/General Info (not needed for setup)<a name="other"/>
* For Grafana:
<br/>
RabbitMQ Dashboard: Dashboard ID 10991 
<br/>
Erlang-Distribution Dashboard: Dashboard ID 11352

* To install pgAdmin:
```
kubectl create ns pgadmin
helm repo add runix https://helm.runix.net/
helm repo update
helm install pgadmin runix/pgadmin4 --namespace=pgadmin \
--set persistence.storageClass=generic --set strategy.type=Recreate
kubectl apply -f resources/pgadmin.yaml
export PGADMIN_POD_NAME=$(kubectl get pods --namespace pgadmin -l "app.kubernetes.io/name=pgadmin4,app.kubernetes.io/instance=pgadmin" -o jsonpath="{.items[0].metadata.name}")
```
To connect to pgAdmin: Connect to your-svc.your-namespace.svc.cluster.local

* To uninstall istio:
```
other/resources/bin/istioctl x uninstall --purge -y
```
