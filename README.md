### Deploying Data E2E Workshop (tested on TKG on AWS)
NOTE:
* Currently requires **cluster-admin** privileges to set up. 
* Currently sets up the Learning Center's user with **cluster-admin** privileges. For this reason, 
it is recommended not to use a permanent Kubernetes cluster, and instead to use a 
temporary Kubernetes cluster that is created on demand and destroyed right after a session (see [here](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-learning-center-about.html#use-cases-1 "Docs"))

#### Kubernetes Cluster Pre-reqs
* Create .env file in root directory (use .env-sample as a template - do NOT check into Git)

* Populate the .env file where possible (NOTE: only a subset of the variables can be populated at the moment.
New entries will be poplated as the install proceeds)

* Create a Management Cluster (Optional - required only if management cluster does not exist) 
```
tanzu management-cluster permissions aws set && tanzu management-cluster create new-data-cluster  --file resources/tanzu-aws.yaml -v 6
```
(NOTE: Follow instructions for deploying a Tanzu Management cluster here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-index.html)

* Create new cluster for Educates platform: 
```
tanzu cluster create tanzu-data-tap-cluster --file resources/tanzu-aws.yaml; watch tanzu cluster get tanzu-data-tap-cluster; tanzu cluster kubeconfig get tanzu-data-tap-cluster --admin
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

* Install Istio: 
```
other/resources/bin/istioctl install --set profile=demo -y; 
#kubectl label pods istio-injection=enabled --selector=<your selector> --namespace=<your namespace>;
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}');
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}');
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}');
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
```


### Install TAP
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
##### imgpkg
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
export TAP_VERSION=1.0.2
export INSTALL_REGISTRY_HOSTNAME=index.docker.io
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.2 --to-repo index.docker.io/oawofolu/tap-packages
kubectl create ns tap-install
tanzu secret registry add tap-registry \
--username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
--server ${INSTALL_REGISTRY_HOSTNAME} \
--export-to-all-namespaces --yes --namespace tap-install
tanzu package repository add tanzu-tap-repository \
--url ${INSTALL_REGISTRY_HOSTNAME}/oawofolu/tap-packages:$TAP_VERSION \
--namespace tap-install
tanzu package repository get tanzu-tap-repository --namespace tap-install
tanzu package available list --namespace tap-install
tanzu package available list tap.tanzu.vmware.com --namespace tap-install
tanzu package available get tap.tanzu.vmware.com/$TAP_VERSION --values-schema --namespace tap-install
source .env
envsubst < resources/tap-values.in.yaml > resources/tap-values.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values.yaml -n tap-install
```

To check on a package's install status: 
```
tanzu package installed get tap<or name pf package> -n tap-install
```

To check that all expected packages were installed successfully: 
```
tanzu package installed list -A -n tap-install
```

- Install tanzu package for learning center:
```
tanzu package available list learningcenter.tanzu.vmware.com --namespace tap-install # To view available packages for learningcenter
tanzu package install learning-center --package-name learningcenter.tanzu.vmware.com --version 0.1.1 -f resources/learning-center-config.yaml -n tap-install
kubectl get all -n learningcenter
tanzu package available list workshops.learningcenter.tanzu.vmware.com --namespace tap-install
```

* If using applications with websocket connections, increase idle timeout on ELB in AWS Management Console to 1 hour (default is 30 seconds)

* Deploy cluster-scoped cert-manager:
```
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
```

* Deploy CERT-MANAGER-ISSUER  (self-signed), CERTIFICATE-SIGNING-REQUEST, CERT-MANAGER-ISSUER (CA): 
```
kubectl apply -f resources/cert-manager-issuer.yaml)
```

* Build workshop image:
(see resources/deploy-workshop.sh)

#Only perform the following if there are 7+ nodes in= the k8s cluster
#- Label a subset of the nodes (for which anti-affinity/affinity rules will apply):
#a=0
#for n in $(kubectl get nodes --selector='!node-role.kubernetes.io/master' --output=jsonpath={.items..metadata.name}); do
  #  if [ $a -eq 0 ]; then kubectl label node $n gpdb-worker=master; fi; 
  #  if [ $a -eq 1 ]; then kubectl label node $n gpdb-worker=segment; fi; 
  #  a=$((a+1)) 
#done

* Build Workshop image and deploy workshop:
```
resources/deploy-workshop.sh
```

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
export MINIO_SERVER_URL=minio.tanzudatatap.ml
kubectl apply -f resources/minio-http-proxy.yaml
```

(TROUBLESHOOTING RECOMMENDED APPROACH:)
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
mc config host add tanzu-data-tap-minio http://minio.tanzudatatap.ml/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
```
on Mac:
```
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core fetch --unshallow
git -C /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask fetch --unshallow
brew install minio/stable/mc
mc config host add tanzu-data-tap-minio http://minio.tanzudatatap.ml/ $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
```

Deploy Minio Chart without TLS:
```
helm repo add minio-legacy https://helm.min.io/
kubectl create ns minio-plain
helm install --set resources.requests.memory=1.5Gi,tls.enabled=false --namespace minio-plain minio minio-legacy/minio --set service.type=LoadBalancer --set service.port=9000
export MINIO_PLAIN_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio-plain| base64 --decode)
export MINIO_PLAIN_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio-plain| base64 --decode)
export MINIO_PLAIN_POD_NAME=$(kubectl get pods --namespace minio-plain -l "release=minio" -o jsonpath="{.items[0].metadata.name}")
export MINIO_PLAIN_SERVER_URL=minio.minio-demo.ml
```

Add required artifacts to Minio (Greenplum-Gemfire connector):
```
mc mb -p data-e2e-minio/artifacts
mc cp other/resources/gemfire/gemfire-greenplum-3.4.1.jar data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar
mc policy set download data-e2e-minio/artifacts/gemfire-greenplum-3.4.1.jar
```

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

* Install Datadog:
```
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog -f other/resources/datadog/data-dog.yaml \
- --set datadog.site='datadoghq.com' --set datadog.apiKey='${DATA_E2E_DATADOG_API_KEY}' datadog/datadog
```

* Install Application Accelerator:
https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-cert-mgr-contour-fcd-install-cert-mgr.html

* Install FluxCD controller:
```
tanzu package available list fluxcd.source.controller.tanzu.vmware.com -n tap-install (ensure packages are listed)
tanzu package install fluxcd-source-controller -p fluxcd.source.controller.tanzu.vmware.com -v 0.16.1 -n tap-install
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
  --version 1.0.2 -n tap-install \
  -f resources/tap-gui-values.yaml
```

Verify installation: 
```
tanzu package installed get tap-gui -n tap-install
```
  
* Install ArgoCD:
```
kubectl create namespace argocd
kubectl apply -n argocd -f resources/argocd.yaml
```

* Install pgAdmin:
```
kubectl create ns pgadmin
helm repo add runix https://helm.runix.net/
helm repo update
helm install pgadmin runix/pgadmin4 --namespace=pgadmin \
--set persistence.storageClass=generic
kubectl apply -f resources/pgadmin.yaml
export PGADMIN_POD_NAME=$(kubectl get pods --namespace pgadmin -l "app.kubernetes.io/name=pgadmin4,app.kubernetes.io/instance=pgadmin" -o jsonpath="{.items[0].metadata.name}")
```
To connect to pgAdmin: Connect to your-svc.your-namespace.svc.cluster.local


* Pre-deploy Greenplum:
```
source .env
resources/setup.sh
```
* Pre-deploy Spring Cloud Data Flow:
```
resources/setup-scdf.sh
```
Register gemfire starter apps:
sink.gemfire=docker:springcloudstream/gemfire-sink-rabbit:2.1.6.RELEASE
source.gemfire=docker:springcloudstream/gemfire-source-rabbit:2.1.6.RELEASE
source.gemfire-cq=docker:springcloudstream/gemfire-cq-source-rabbit:2.1.6.RELEASE

* Build secondary cluster:
Create new cluster:
```
tanzu cluster create tanzu-data-tap-secondary --file resources/tanzu-aws-secondary.yaml
tanzu cluster kubeconfig get tanzu-data-tap-secondary --admin
```
** NOTE: The following instructions should be applied to the new cluster created above.**
Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain):
```    
kubectl apply -f resources/storageclass.yaml
kubectl patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

Create the network policy 
```
kubectl apply -f resources/networkpolicy.yaml
```

Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
```    
kubectl apply -f resources/podsecuritypolicy.yaml
```

Install Contour: (NOTE: Change the Loadbalancer's healthcheck from HTTP to TCP in the AWS Console)
```
kubectl apply -f https://projectcontour.io/quickstart/v1.18.2/contour.yaml
```

Install the Kubernetes Metrics server: 
```
kubectl apply -f resources/metrics-server.yaml; watch kubectl get deployment metrics-server -n kube-system
```
  
Install cert-manager:
```
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
kubectl apply -f resources/cert-manager-issuer.yaml
```
  
Install Gemfire operator:
```
  source .env
  kubectl create ns gemfire-system --dry-run -o yaml | kubectl apply -f -
  kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username="$DATA_E2E_PIVOTAL_REGISTRY_USERNAME" --docker-password="$DATA_E2E_PIVOTAL_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -
  helm uninstall  gemfire --namespace gemfire-system; helm install gemfire other/resources/gemfire/gemfire-operator-1.0.3/ --namespace gemfire-system
```

Install Gemfire cluster:
```
kubectl create secret docker-registry app-image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username="$DATA_E2E_REGISTRY_USERNAME" --docker-password="$DATA_E2E_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -
kubectl apply -f other/resources/gemfire/gemfire-cluster-with-gateway-receiver-ny.yaml -n gemfire-system
```   
Install Istio:
(In primary cluster)
```
other/resources/istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=other/resources/istio-1.13.2/manifests -y
```
(In secondary cluster)
```
other/resources/istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=other/resources/istio-1.13.2/manifests -y
```
Install SealedSecrets:
```
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.4/controller.yaml
```
  
Generate kubeconfig for accessing secondary cluster: (Must install kubeseal: https://github.com/bitnami-labs/sealed-secrets)
(Apply to secondary cluster:)
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

(Apply to primary cluster:)
```
kubectl apply -f resources/kconfigsealedsecret.yaml
```
  
#### Other

* Integrate Wavefront:
Wavefront Token: d0bc6a3f-580c-4212-8b35-1c6edd1e4ffb
Wavefront URI: vmware.wavefront.com
Source: 3a4316f6-6501-4750-587b-939e

* For Grafana:
RabbitMQ Dashboard: Dashboard ID 10991 
Erlang-Distribution Dashboard: Dashboard ID 11352

* Uninstall istio:
```
other/resources/bin/istioctl x uninstall --purge -y
```