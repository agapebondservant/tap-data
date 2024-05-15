### Deploying Data E2E Workshop (tested on TKG on AWS)

NOTE:
* Currently requires **cluster-admin** privileges to set up.
* Currently sets up the Learning Center's user with **cluster-admin** privileges. For this reason,
  it is recommended not to use a permanent Kubernetes cluster, and instead to use a
  temporary Kubernetes cluster that is created on demand and destroyed right after a session (see [here](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-learning-center-about.html#use-cases-1 "Docs"))

## NOTE: For WORKSHOPS-AS-A-SERVICE <a name="workshops-as-a-service"/>
For Workshops-as-a-Service, follow the instructions in this section.
(The rest of this guide should not apply except where indicated.)

Pre-requisites: A Kubernetes cluster with TAP installed - see [Install TAP](#tap-install)

* Run the script: `resources/scripts/workshop-as-a-service/setup.sh`

* Once the script has completed successfully, deploy the workshops below:
    - workshop/workshop-postgres-deepdive.yaml
    - workshop/workshop-rabbitmq-commercial-features.yaml
    - workshop/workshop-mysql-deepdive.yaml
    - workshop/workshop-data-with-tap.yaml

## Contents
1. [For Workshops-as-a-Service](#workshops-as-a-service)
2. [Kubernetes Cluster Prep](#pre-reqs)
3. [Install Minio](#minio)
4. [Install Prometheus and Grafana](#prometheusgrafana)
5. [Install Wavefront](#wavefront)
6. [Install Kubeapps](#kubeapps)
7. [Install Datadog](#datadog)
8. [Install ArgoCD](#argocd)
9. [Install Gemfire](#gemfirepredeploy)
10. [Install OperatorUI](#operatorui)
11. [Pre-deploy Greenplum and Spring Cloud Data Flow](#predeploys)
12. [Install Kubeflow Pipelines](#kubeflowpipelines)
13. [Deploy Argo Workflows](#argoworkflows)
14. [Build secondary cluster (for multi-site demo)](#multisite)
15. [Install TAP](#tap-install)
16. [Setup Tanzu Developer Portal Backstage Configurator](#tdp)
17. [Deploy Tanzu Data Workshops](#buildanddeploy)
18. [Deploy Single Workshop to Pre-Existing LearningCenter Portal](#buildsingle)
19. [Create Carvel Packages for Dependencies](#carvelpackages)
20. [Other: How-tos/General Info (not needed for setup)](#other)

#### Kubernetes Cluster Prep<a name="pre-reqs"/>
* Create .env file in root directory (use .env-sample as a template - do NOT check into Git)

* Populate the .env file where possible (NOTE: only a subset of the variables can be populated at the moment.
New entries will be populated as the install proceeds)

* Install the appropriate version of the kubectl version for the desired version of TAP (see below to confirm if a new version of Kubernetes is needed).

FOR TKG:
--------

* Download the latest version of the tanzu cli (see link: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.6/tap/install-tanzu-cli.html)

* Run the following if a Kubernetes cluster upgrade is needed (see TAP version support matrix: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.6/tap/k8s-matrix.html):
```
export TARGET_TKG_VERSION=2.2.0 #or desired target TKG version
chmod +x tanzu 
tanzu plugin install --group vmware-tkg/default:v$TARGET_TKG_VERSION 
cp  ~/.config/tanzu/tkg/compatibility/tkg-compatibility.yaml  ~/.config/tanzu/tkg/compatibility/tkg-compatibility-2.1.1.yaml
rm ~/.config/tanzu/tkg/compatibility/tkg-compatibility.yaml
tanzu context use # select appropriate management cluster, for TKG versions 2.3.0 or higher
tanzu login # select appropriate management cluster, for TKG versions 2.2.0 or lower
tanzu mc kubeconfig get --admin
kubectl config use-context <selected context>
AWS_REGION=<your-region> tanzu mc upgrade --yes
kubectl version
```

* Create a Management Cluster (Optional - required only if management cluster does not exist) 
```
AWS_REGION=<your-region> tanzu management-cluster permissions aws set && tanzu management-cluster create <your-management-cluster-name>  --file resources/tanzu-management-aws.yaml  -v 6
```
(NOTE: Follow instructions for pre-requisites to deploy a Tanzu Management cluster here: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-index.html)

* Create new cluster for Educates platform: 
```
tanzu login (select the management cluster when prompted)
tanzu config set features.cluster.allow-legacy-cluster true # only applies for TKG 2.1+
AWS_REGION=<your-region> tanzu cluster create --file resources/tanzu-aws.yaml
tanzu cluster kubeconfig get <your-cluster-name> --admin
kubectl config use-context <your-cluster-name>-admin@<your-cluster-name>
```

FOR GKE:
--------
* Login:
```
gcloud auth login
```

* Ensure that the user returned by `gcloud info` has **Kubernetes Engine Admin** privileges: 
under IAM -> View Princiapls, select the user returned above and add the **Kubernetes Engine Admin** role.

* Switch to the K8s cluster context:
```
gcloud container clusters get-credentials mlops-gke --zone us-east1-c --project pa-oawofolu
```

* Populate a ConfigMap based on the .env file
```
kubectl delete configmap data-e2e-env || true; sed 's/export //g' .env > .env-properties && kubectl create configmap data-e2e-env --from-env-file=.env-properties && rm .env-properties
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

* (On AWS) Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain) 
```
kubectl apply -f resources/storageclass.yaml
```

* (On AWS) Mark the storage class as default: 
```
kubectl patch storageclass generic -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

* (On AWS EKS) Deploy the EBS CSI Driver (requires eksctl cli - see <a href="https://eksctl.io/installation/" target="_blank">eksctl cli</a> and <a href="https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" target="_blank">AWS cli</a>):
```
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster <your-cluster-name> \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve
eksctl create addon --name aws-ebs-csi-driver \
    --cluster <your-cluster-name> \
    --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole \
    --force
```

* (On GCP) Mark the storage class as default:
```
kubectl apply -f resources/storageclass-gke.yaml
kubectl patch storageclass standard-rwo -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

* Create the network policy (networkpolicy.yaml - uses allow-all-ingress for now)
```
kubectl apply -f resources/networkpolicy.yaml
```

* Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
```
kubectl apply -f resources/podsecuritypolicy.yaml
```

* Install Contour: (NOTE: Change the Loadbalancer's healthcheck from HTTP to TCP in the AWS Console, and change the AWS loadbalancer timeout from 60 seconds to 3600 seconds):
```
kubectl apply -f https://projectcontour.io/quickstart/v1.18.2/contour.yaml # For TAP 1.3 and below
kubectl apply -f https://projectcontour.io/quickstart/v1.24.3/contour.yaml # For TAP 1.5
```

* Install the Kubernetes Metrics server: 
```
kubectl apply -f resources/metrics-server.yaml; watch kubectl get deployment metrics-server -n kube-system
```

* Deploy Tanzu Cluster Essentials: see https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.8/cluster-essentials/deploy.html

* Deploy cluster-scoped cert-manager:
```
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml # For TAP 1.3 and below
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml # For TAP 1.5+
```

* (On AWS): Deploy CERT-MANAGER-ISSUER  (self-signed), CERTIFICATE-SIGNING-REQUEST, CERT-MANAGER-ISSUER (CA):
```
kubectl apply -f resources/cert-manager-issuer.yaml
```

* (On GKE): Set up ServiceAccount secret (see "Use Static Credentials": https://cert-manager.io/docs/configuration/acme/dns01/google/)
```
PROJECT_ID=<YOUR-GCP-PROJECT-ID>
gcloud iam service-accounts create dns01-solver --display-name "dns01-solver" #this should be run on GCP
gcloud iam service-accounts keys create key.json \
   --iam-account dns01-solver@$PROJECT_ID.iam.gserviceaccount.com
kubectl create secret generic clouddns-dns01-solver-svc-acct -n cert-manager \
   --from-file=key.json
```

* (On GCP): Deploy ClusterIssuer, Certificate, SecretExport:
```
kubectl apply -f resources/cert-manager-issuer-gke.yaml
rm key.json
```

* Set up Secrets:
```
kubectl create secret docker-registry registry-credentials --docker-server=https://index.docker.io/v1/ --docker-username=${DATA_E2E_REGISTRY_USERNAME} --docker-password=${DATA_E2E_REGISTRY_PASSWORD} --dry-run -o yaml | kubectl apply -f -
kubectl annotate secret registry-credentials secretgen.carvel.dev/image-pull-secret=""
kubectl create secret docker-registry tanzu-image-pull-secret --docker-server=registry.tanzu.vmware.com --docker-username=${DATA_E2E_PIVOTAL_REGISTRY_USERNAME} --docker-password=${DATA_E2E_PIVOTAL_REGISTRY_PASSWORD} --dry-run -o yaml | kubectl apply -f -
kubectl annotate secret tanzu-image-pull-secret secretgen.carvel.dev/image-pull-secret=""
```

* Install SealedSecrets:
```
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.5/controller.yaml
```

* Expose Kube-DNS service:
```
kubectl apply -f resources/kube-dns.yaml
```

* Install External Secrets:
```
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets \
    --create-namespace
```

* Install Vault: (First install Vault CLI locally: https://developer.hashicorp.com/vault/downloads)
```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --set='server.ha.enabled=true' --set='server.ha.raft.enabled=true' -n vault --create-namespace --wait
watch kubectl get pod -nvault #NOTE: will not show "Ready" until the rest of the steps below are executed

resources/scripts/setup-vault.sh

kubectl create secret generic vault-token --from-literal token=$(cat cluster-keys.json | jq -r ".root_token") -n vault
kubectl apply -f other/resources/vault/vault-clustersecretstore.yaml
```

* Set up RBAC for Service Bindings:
```
kubectl apply -f resources/service-binding-rbac.yaml
```

* Install Istio: (used by Multi-site workshops, Gemfire workshops)
```
istio-1.13.2/bin/istioctl install --set profile=demo -y; 
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
kubectl create ns minio
kubectl create secret generic tls-ssl-minio --from-file=private.key  --from-file=tls.key=private.key --from-file=public.crt  --from-file=tls.crt=public.crt --from-file=ca.crt=public.crt --namespace minio
helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,auth.rootUser=minio,ingress.enabled=true,ingress.hostname=${DATA_E2E_MINIO_URL},ingress.selfSigned=true,tls.autoGenerated=true \
--namespace minio minio bitnami/minio
#helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,auth.rootUser=minio,auth.rootPassword=minio123,tls.existingSecret=tls-ssl-minio \
#--namespace minio minio oci://registry-1.docker.io/bitnamicharts/minio
kubectl apply -f resources/minio-bitnami-http-proxy.yaml
export DATA_E2E_MINIO_TLS_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.root-user}" -n minio| base64 --decode)
export DATA_E2E_MINIO_TLS_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.root-password}" -n minio| base64 --decode)

#helm repo add minio-legacy https://helm.min.io/
#kubectl create secret generic tls-ssl-minio --from-file=tls.key --from-file=tls.crt --namespace minio

#helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,tls.certSecret=tls-ssl-minio --namespace minio minio minio-legacy/minio
#helm install --set resources.requests.memory=1.5Gi,tls.enabled=true,tls.publicCrt=tls.crt,tls.privateKey=tls.key,tls.certSecret=tls-ssl-minio --namespace minio minio minio-legacy/minio

#export DATA_E2E_MINIO_TLS_ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)
#export DATA_E2E_MINIO_TLS_SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)
echo $DATA_E2E_MINIO_TLS_ACCESS_KEY $DATA_E2E_MINIO_TLS_SECRET_KEY # update .env with the values of DATA_E2E_MINIO_TLS_ACCESS_KEY, DATA_E2E_MINIO_TLS_SECRET_KEY
source .env
export MINIO_SERVER_URL=$DATA_E2E_MINIO_URL
#kubectl apply -f resources/minio-http-proxy.yaml
```

(TROUBLESHOOTING RECOMMENDED APPROACH: NOT used by this workshop)
```
helm repo add minio-operator https://charts.min.io/
kubectl create namespace minio-operator || true
kubectl apply -f resources/minio-tls-cert.yaml -n minio-operator
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
--set prometheus.service.port=8000 --set prometheus.service.type=LoadBalancer \
--set grafana.enabled=false,alertmanager.enabled=false,nodeExporter.enabled=false \
--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.shards=0 \
--wait
kubectl apply -f resources/prometheus-httpproxy.yaml
```

Grafana:
```
helm install grafana bitnami/grafana --namespace monitoring-tools
export DATA_E2E_GRAFANA_PASSWORD=$(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)
echo $DATA_E2E_GRAFANA_PASSWORD # update .env file with value of DATA_E2E_GRAFANA_PASSWORD
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

#### Install Kubeapps <a name="kubeapps"/>
```
helm install kubeapps bitnami/kubeapps \
--set frontend.service.type=LoadBalancer \
--set packaging.carvel.enabled=true \
--set ingress.enabled=true \
--set ingress.hostname=kubeapps.${DATA_E2E_BASE_URL} \
--set ingress.annotations."projectcontour\.io/websocket-routes"='/' \
--namespace kubeapps \
--create-namespace
kubectl apply -f resources/kubeapps-httpproxy.yaml -nkubeapps
```

To get the Kubeapps Service URL (note: the URL may take several seconds to launch in a browser):
```
export KUBEAPPS_SERVICE_IP=$(kubectl get svc --namespace kubeapps kubeapps -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}");
echo "http://${KUBEAPPS_SERVICE_IP}"
```

To create a new Kubeapps user *kubeappsuser* and its API token:
```
kubectl delete serviceaccount kubeappuser -n kubeapps || true
kubectl create -n kubeapps serviceaccount kubeappuser
kubectl create clusterrolebinding kubeappuserkubeappsbinding --clusterrole=cluster-admin --serviceaccount=kubeapps:kubeappuser
kubectl create token kubeappuser -n kubeapps
```

To uninstall:
```
helm uninstall kubeapps -n kubeapps
kubectl delete ns kubeapps
```

#### Install Wavefront <a name="wavefront"/>
```
source </path/to/env/file>
kubectl apply -f https://raw.githubusercontent.com/wavefrontHQ/observability-for-kubernetes/main/deploy/wavefront-operator.yaml
kubectl create -n observability-system secret generic wavefront-secret --from-literal token=${DATA_E2E_WAVEFRONT_ACCESS_TOKEN}
kubectl apply -f other/resources/wavefront/wavefront-crd.yaml
kubectl apply -f other/resources/wavefront/wavefront-configmap.yaml
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

#### Install Argo Workflows cli <a name="argoworkflowscli"/>
```
cd other/resources/argocd
docker build -t ${DATA_E2E_REGISTRY_USERNAME}/argocli:latest .
docker push ${DATA_E2E_REGISTRY_USERNAME}/argocli:latest
cd -
```

#### Install Gemfire <a name="gemfirepredeploy"/>
* Install Gemfire:
```
source .env
export GEMFIRE_NAMESPACE_NM=gemfire-system
export GEMFIRE_VER=2.2.0
kubectl create ns $GEMFIRE_NAMESPACE_NM || true
kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f -
kubectl annotate secret image-pull-secret secretgen.carvel.dev/image-pull-secret=""
helm install  gemfire-crd oci://registry.tanzu.vmware.com/tanzu-gemfire-for-kubernetes/gemfire-crd --version $GEMFIRE_VER --namespace $GEMFIRE_NAMESPACE_NM --set operatorReleaseName=gemfire-operator
helm install gemfire-operator oci://registry.tanzu.vmware.com/tanzu-gemfire-for-kubernetes/gemfire-operator --version $GEMFIRE_VER --namespace $GEMFIRE_NAMESPACE_NM
```

#### Install Operator UI <a name="operatorui"/>
* Install Operator UI: (must have pre-installed Tanzu Data operators)
```
other/resources/operator-ui/crd_annotations/apply-annotations
kubectl create namespace operator-ui
kubectl create configmap kconfig --from-file </path/to/multicluster/kubeconfig> --namespace operator-ui
kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-app.yaml --namespace operator-ui
kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-httpproxy.yaml --namespace operator-ui #only if using ProjectContour for Ingress
watch kubectl get all -noperator-ui
```

#### Pre-deploy Greenplum and Spring Cloud Data Flow<a name="predeploys"/>
* Pre-deploy Greenplum for Kubernetes: (only required for these workshops: <b>Greenplum Workshops</b>)
```
source .env
resources/scripts/setup.sh
```
* Pre-deploy Greenplum on AWS Marketplace: see <a href="https://aws.amazon.com/marketplace/pp/prodview-piiukzn26stas" target="_blank">link</a>
* Pre-deploy Spring Cloud Data Flow: (only required for these workshops: <b>RabbitMQ Workshops, Gemfire Workshops, Greenplum Workshops, ML/AI workshops</b>)
```
resources/scripts/setup-scdf-1.3.sh
```
Register additional starter apps:
sink.gemfire=docker:springcloudstream/gemfire-sink-rabbit:2.1.6.RELEASE
source.gemfire=docker:springcloudstream/gemfire-source-rabbit:2.1.6.RELEASE
source.gemfire-cq=docker:springcloudstream/gemfire-cq-source-rabbit:2.1.6.RELEASE
source.trigger=https://repo.spring.io/artifactory/release/org/springframework/cloud/stream/app/trigger-source-rabbit/2.1.4.RELEASE/trigger-source-rabbit-2.1.4.RELEASE.jar

#### Deploy Kubeflow Pipelines <a name="kubeflowpipelines"/>
* Deploy Kubeflow Pipelines:

See [this link](https://github.com/agapebondservant/kubeflow-pipelines-accelerator)

#### Deploy Argo Workflows <a name="argoworkflows"/>
* Deploy Argo Workflows:
```
kubectl create ns argo | true
kubectl apply -f other/resources/argo-workflows/argo-workflow.yaml -nargo 
kubectl apply -f other/resources/argo-workflows/argo-workflow-http-proxy.yaml -nargo
kubectl create rolebinding default-admin --clusterrole=admin --serviceaccount=argo:default -n argo
kubectl apply -f other/resources/argo-workflows/argo-workflow-rbac.yaml -nargo
```


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

* Install SealedSecrets:
```
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.4/controller.yaml
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

* Expose Kube-DNS service:
```
kubectl apply -f resources/kube-dns.yaml
```

* Install Istio:
- (In primary cluster)
```
istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=istio-1.13.2/manifests -y
```
- In the *Loadbalancer* created, add a new port 53 with an instance port that has not already been generated between 30000-32767.
- (In secondary cluster)
```
istio-1.13.2/bin/istioctl install --set profile=demo-tanzu --set installPackagePath=istio-1.13.2/manifests -y
```
- In the *Loadbalancer* created, add a new port 53 with an instance port that has not already been generated between 30000-32767.
  
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

rm -f myfile 
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
export TANZU_CLI_VSN=2.1.1 #set to blank for TKG 1.6 and below
mkdir -p $HOME/tanzu$TANZU_CLI_VSN
export TANZU_CLI_NO_INIT=true
cd $HOME/tanzu$TANZU_CLI_VSN
sudo install cli/core/0.11.1/tanzu-core-linux_amd64 /usr/local/bin/tanzu # for TKG 1.6 and below
sudo install cli/core/v0.28.1/tanzu-core-linux_amd64 /usr/local/bin/tanzu #for TKG 2.1.1 and above
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
#export TAP_VERSION=1.1.1
#export TAP_VERSION=1.2.0
export TAP_VERSION=1.7.1
export INSTALL_REGISTRY_HOSTNAME=index.docker.io #https://index.docker.io/v1/ # index.docker.io
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tap-packages
imgpkg copy -b registry.tanzu.vmware.com/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:${DATA_E2E_RABBIT_OPERATOR_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/oawofolu/vmware-tanzu-rabbitmq
imgpkg copy -b registry.tanzu.vmware.com/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:${DATA_E2E_RABBIT_OPERATOR_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/oawofolu/tanzu-rabbitmq-package-repo
imgpkg copy -b registry.tanzu.vmware.com/tanzu-gemfire-for-kubernetes/gemfire-for-kubernetes-carvel-bundle:${DATA_E2E_GEMFIRE_OPERATOR_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/oawofolu/gemfire-operator
```

#### Install TAP
```
kubectl create ns tap-install
# tanzu secret registry add tap-registry \
#--username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
#--server ${INSTALL_REGISTRY_HOSTNAME} \
#--export-to-all-namespaces --yes --namespace tap-install
tanzu secret registry add registry-credentials \
--username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
--server ${INSTALL_REGISTRY_HOSTNAME} \
--export-to-all-namespaces --yes --namespace tap-install
kubectl apply -f resources/tap-rbac.yaml -n default
kubectl apply -f resources/tap-rbac-2.yaml -n default

tanzu package repository add tanzu-tap-repository \
--url ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tap-packages:$TAP_VERSION \
--namespace tap-install
tanzu package repository get tanzu-tap-repository --namespace tap-install
tanzu package available list --namespace tap-install
tanzu package available list tap.tanzu.vmware.com --namespace tap-install
tanzu package available get tap.tanzu.vmware.com/$TAP_VERSION --values-schema --namespace tap-install
export TBS_VERSION=1.9.0 # if installing TAP 1.3
export TBS_VERSION=1.10.8 # if installing TAP 1.5
export TBS_VERSION=1.7.1 # if installing TAP 1.7.1
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-tbs-deps-package-repo:${TBS_VERSION} --to-repo index.docker.io/oawofolu/tbs-full-deps # for TAP <1.7
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-deps-package-repo:${TBS_VERSION} \
--to-repo index.docker.io/oawofolu/tbs-full-deps # for TAP 1.7+

#If installing TAP 1.2:
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values.yaml -n tap-install #ignore any errors at this stage
envsubst < resources/tap-values-tbsfull.in.yaml > resources/tap-values-tbsfull.yaml

#If installing TAP 1.3:
envsubst < resources/tap-values-1.3.in.yaml > resources/tap-values-1.3.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values-1.3.yaml -n tap-install

#If installing TAP 1.5:
envsubst < resources/tap-values-1.5.in.yaml > resources/tap-values-1.5.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values-1.5.yaml -n tap-install

# If installing TAP 1.7+:
kubectl create ns tap-gui
kubectl create serviceaccount tap-gui -n tap-gui || true
kubectl create clusterrolebinding tap-gui-cluster-admin --serviceaccount=default:tap-gui --clusterrole=cluster-admin || true
kubectl apply -f resources/tap-gui-token.yaml -n tap-gui || true
export TAP_1_7_KUBECONFIG_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
export TAP_1_7_KUBECONFIG_CA_B64=$(echo ${TAP_1_7_KUBECONFIG_CA} | base64 --decode)
export TAP_1_7_KUBEURL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
export TAP_1_7_KUBETOKEN=$(kubectl -n tap-gui get secret tap-gui -o=json | jq -r '.data["token"]' | base64 --decode)
envsubst < resources/tap-values-1.7.in.yaml > resources/tap-values-1.7.yaml
envsubst < resources/tap-values-1.7-buildservice.in.yaml > resources/tap-values-1.7-buildservice.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values-1.7.yaml -n tap-install
tanzu package repository add full-deps-package-repo --url ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tbs-full-deps:$TBS_VERSION --namespace tap-install
tanzu package install full-deps -p full-deps.buildservice.tanzu.vmware.com -v "> 0.0.0" -n tap-install --values-file resources/tap-values-1.7-buildservice.yaml

# If upgrading to TAP 1.6.2:
kubectl create serviceaccount tap-gui || true
kubectl create clusterrolebinding tap-gui-cluster-admin --serviceaccount=default:tap-gui --clusterrole=cluster-admin || true
kubectl create token tap-gui || true
export TAP_1_6_KUBECONFIG_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
export TAP_1_6_KUBECONFIG_CA_B64=$(echo ${TAP_1_6_KUBECONFIG_CA} | base64 --decode)
export TAP_1_6_KUBEURL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
export TAP_1_6_KUBETOKEN=tap-gui
envsubst < resources/tap-values-1.6.in.yaml > resources/tap-values-1.6.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v 1.6.2 --values-file resources/tap-values-1.6.yaml -n tap-install
tanzu package repository add full-deps-package-repo --url ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/full-deps-package-repo:1.6.2 --namespace tap-install
tanzu package install full-deps -p full-deps.buildservice.tanzu.vmware.com -v "> 0.0.0" -n tap-install --values-file resources/tap-values-1.6.yaml

# If upgrading to TAP 1.7+:
kubectl create serviceaccount tap-gui || true
kubectl create clusterrolebinding tap-gui-cluster-admin --serviceaccount=default:tap-gui --clusterrole=cluster-admin || true
kubectl create token tap-gui || true
export TAP_1_7_KUBECONFIG_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
export TAP_1_7_KUBECONFIG_CA_B64=$(echo ${TAP_1_7_KUBECONFIG_CA} | base64 --decode)
export TAP_1_7_KUBEURL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
export TAP_1_7_KUBETOKEN=tap-gui
envsubst < resources/tap-values-1.7.in.yaml > resources/tap-values-1.7.yaml
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file resources/tap-values-1.7.yaml -n tap-install
envsubst < resources/tap-values-1.7-buildservice.in.yaml > resources/tap-values-1.7-buildservice.yaml
tanzu package repository add full-deps-package-repo --url ${INSTALL_REGISTRY_HOSTNAME}/${DATA_E2E_REGISTRY_USERNAME}/tbs-full-deps:$TBS_VERSION --namespace tap-install
tanzu package install full-deps -p full-deps.buildservice.tanzu.vmware.com -v "> 0.0.0" -n tap-install --values-file resources/tap-values-1.7-buildservice.yaml
kubectl apply -f resources/clusterbuilders.yaml -ndefault

tanzu package installed delete tap -n tap-install -y 
# may require manually clearing the finalizers for each stuck package - get the list of stuck packages by running 
kubectl get packageinstall -ntap-install
kubectl edit packageinstall/tap -ntap-install
# Then edit the finalizers list to an empty list - finalizers: []

#If installing TAP 1.2:
tanzu package installed update tap -p tap.tanzu.vmware.com --values-file resources/tap-values-tbsfull.yaml -n tap-install

#If installing TAP 1.3:
tanzu package installed update tap -p tap.tanzu.vmware.com --values-file resources/tap-values-1.3.yaml -n tap-install
```

To check on a package's install status:
```
tanzu package installed get tap<or name pf package> -n tap-install
```

To check that all expected packages were installed successfully:
```
tanzu package installed list -A -n tap-install
```

For any packages above that still shows "Reconciliation failed", try deleting and reinstalling - thus:
```
tanzu package installed delete <name of failed package> -n tap-install -y
tanzu package install <name of failed package> -p <package metadata name> -v ${package version}  -n tap-install
```

Deploy LearningCenter:
For TAP <1.7:
```
tanzu package available list learningcenter.tanzu.vmware.com --namespace tap-install # To view available packages for learningcenter
tanzu package install learning-center -p learningcenter.tanzu.vmware.com --version 0.2.7 --values-file resources/learning-center-config.yaml -n tap-install
kubectl get all -n learningcenter
tanzu package available list workshops.learningcenter.tanzu.vmware.com --namespace tap-install
```
For TAP 1.7 (Installs the package repository in a separate namespace; the default package repository for TAP 1.7 no longer includes LearningCenter)
```
envsubst < resources/tap-values-1.7-learningcenter.in.yaml > resources/tap-values-1.7-learningcenter.yaml;
kubectl create ns tap-install-learningcenter;
tanzu secret registry add tap-registry --username $DATA_E2E_PIVOTAL_REGISTRY_USERNAME \
 --password $DATA_E2E_PIVOTAL_REGISTRY_PASSWORD --server registry.tanzu.vmware.com \
 --export-to-all-namespaces --yes --namespace tap-install;
tanzu package repository add tanzu-tap-repository-learningcenter \
--url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.6.5 \
--namespace tap-install-learningcenter; # Accept EULA when prompted\
tanzu package install learningcenter -p learningcenter.tanzu.vmware.com -v "> 0.0.0" \
--values-file resources/tap-values-1.7-learningcenter.yaml --namespace tap-install-learningcenter;
kubectl apply -f resources/learning-center-config.yaml;
```

* (Optional) Deploy the sample Learning Center Workshop:
```
kubectl apply -f resources/workshop-sample.yaml
kubectl apply -f resources/training-portal-sample.yaml
watch kubectl get learningcenter-training
```

Deploy Bitnami Services - first deploy pre-requisities (Crossplane and Service Toolkit packages:
```
tanzu package available list -n tap-install crossplane.tanzu.vmware.com
tanzu package install crossplane -n tap-install -p crossplane.tanzu.vmware.com -v 0.3.0 # or version  number genrated above)
tanzu package available list -n tap-install services-toolkit.tanzu.vmware.com
tanzu package install services-toolkit -n tap-install -p services-toolkit.tanzu.vmware.com -v 0.12.0 # or version number generated above
```
```
tanzu package available list -n tap-install bitnami.services.tanzu.vmware.com
BITNAMI_VERSION_NUMBER=0.3.1 # or existing bitnami package
tanzu package install bitnami-services -n tap-install -p bitnami.services.tanzu.vmware.com -v $BITNAMI_VERSION_NUMBER
```

Publish Accelerators:
```
tanzu plugin install --local <path-to-tanzu-cli> all
tanzu acc create mlflow --git-repository https://github.com/agapebondservant/mlflow-accelerator.git --git-branch main
tanzu acc create jupyter --git-repository https://github.com/agapebondservant/jupyter-accelerator.git --git-branch main
tanzu acc create appcollator --git-repository https://github.com/agapebondservant/app-collator.git --git-branch main
tanzu acc create mlmetrics --git-repository https://github.com/agapebondservant/ml-metrics-accelerator.git --git-branch main
tanzu acc create scdf-mlmodel --git-repository https://github.com/agapebondservant/scdf-ml-model.git --git-branch main
tanzu acc create kubeflow-pipelines --git-repository https://github.com/agapebondservant/kubeflow-pipelines-accelerator.git --git-branch main
tanzu acc create sample-cnn-app --git-repository https://github.com/tanzumlai/sample-ml-app.git --git-branch main
tanzu acc create mlflowrunner --git-repository https://github.com/tanzumlai/mlcode-runner.git --git-branch main
tanzu acc create datahub --git-repository https://github.com/agapebondservant/datahub-accelerator.git --git-branch main
tanzu acc create servicebinding --git-repository https://github.com/agapebondservant/external-service-binding-accelerator.git --git-branch main
tanzu acc create pgadmin --git-repository https://github.com/agapebondservant/pgadmin-accelerator.git --git-branch main
tanzu acc create argo-pipelines-acc --git-repository https://github.com/agapebondservant/argo-workflows-accelerator.git --git-branch main
tanzu acc create in-db-analytics-acc --git-repository https://github.com/agapebondservant/in-database-analytics-accelerator.git --git-branch main
tanzu acc create argo-pipelines-kapp-acc --git-repository https://github.com/agapebondservant/sample-argo-workflow-kappcontroller-accelerator.git --git-branch main
tanzu acc create mlplatform --git-repository https://github.com/agapebondservant/mlplatform-accelerator.git --git-branch main
tanzu acc create airflow --git-repository https://github.com/agapebondservant/airflow-accelerator.git --git-branch main
tanzu acc create postgres --git-repository https://github.com/agapebondservant/postgres-accelerator.git --git-branch main
tanzu acc create mlplatform --git-repository https://github.com/agapebondservant/mlplatform-accelerator.git --git-branch main
tanzu acc create mlcoderunner --git-repository https://github.com/tanzumlai/mlcode-runner.git --git-branch main

tanzu acc fragment create bitnami-jupyter-fragment --git-repository https://github.com/agapebondservant/jupyter-accelerator.git --git-branch bitnami
tanzu acc fragment create airflow-fragment --git-repository https://github.com/agapebondservant/airflow-accelerator.git --git-branch main
tanzu acc fragment create kubeflowpipelines-fragment --git-repository https://github.com/agapebondservant/kubeflow-pipelines-accelerator.git --git-branch bitnami
tanzu acc fragment create bitnami-mlflow-fragment --git-repository https://github.com/agapebondservant/mlflow-accelerator.git --git-branch bitnami
tanzu acc fragment create postgres-fragment --git-repository https://github.com/agapebondservant/postgres-accelerator.git --git-branch main
tanzu acc fragment create bitnami-ray-fragment --git-repository https://github.com/agapebondservant/ray-accelerator.git --git-branch bitnami

```

Install Auto API Registration:
```
tanzu package available list apis.apps.tanzu.vmware.com --namespace tap-install #retrieve available version
export API_REG_VERSION=0.4.1 # or existing Auto API package
tanzu package install api-auto-registration \
-p apis.apps.tanzu.vmware.com \
--namespace tap-install \
--version $API_REG_VERSION \
--values-file resources/tap-api-values.yaml
```

Verify that installation was successful:
```
tanzu package installed get api-auto-registration -n tap-install
kubectl get pods -n api-auto-registration
```

Install Flux Kustomize and Helm controllers:
```
brew install fluxcd/tap/flux@0.41
flux install -n flux-system --components kustomize-controller --version v0.41.2
flux install -n flux-system --components helm-controller --version v0.41.2
```

* Install Analytics Apps:
Create a namespace for the analytics apps:
```
kubectl create ns streamlit
```

The Analytics apps should reside on their own exclusive nodes.
Apply taints and affinities to 2 of the nodes in the cluster:
```
kubectl get nodes
kubectl taint nodes <FIRST NODE TO TAINT> analytics=anomaly:NoSchedule
kubectl taint nodes <SECOND NODE TO TAINT> analytics=anomaly:NoSchedule
kubectl label nodes <FIRST NODE TO LABEL> analytics=anomaly
kubectl label nodes <SECOND NODE TO LABEL> analytics=anomaly
```

Deploy the Analytics apps and dependencies:
```
other/resources/analytics/anomaly-detection-demo/scripts/deploy-apps-and-rabbit-bindings.sh
other/resources/analytics/anomaly-detection-demo/scripts/deploy-rabbit.sh

# For accessing endpoints locally:
other/resources/analytics/anomaly-detection-demo/scripts/port-forward-apps.sh

# For exposing externally accessible endpoints:
kubectl apply -f other/resources/analytics/anomaly-detection-demo/dashboard-httpproxy.yaml -nstreamlit
```

### Setup Tanzu Developer Portal Backstage Configurator<a name="tdp"/>
(NOTE: Manual used was https://github.com/benjaminleesmith/docs-tap/blob/main/tap-gui/configurator/create-plug-in-wrapper.hbs.md)

Update any dependency versions (under the "dependencies" block in package.json) as appropriate - update
```
</path/to/frontend>/package.json #Make appropriate updates
</path/to/backend>/package.json #Make appropriate updates
```

Build and publish the non-external Backstage frontend plugins that you wish to integrate with the Portal (update plugin version when prompted):
```
cd </path/to/frontend>/src
yarn install && yarn tsc && yarn build
yarn publish
```

Build and publish the non-external Backstage backend plugins that you wish to integrate with the Portal (update plugin version when prompted):
```
cd </path/to/backend>/src
yarn install && yarn tsc && yarn build
yarn publish
```

* Enable RBAC permissions for the TDP user (**tap-gui** by default - update as appropriate):
```
kubectl apply -f other/resources/tdp/tdp-rbac.yaml
```

* Update the TDP config if necessary with the latest **app** and **backend** plugins: update
```
other/resources/tdp/tdp-config.yaml
```

* Deploy the TDP Configurator Workload:
```
export TDP_CONFIG_STR=$(base64 -i other/resources/tdp/tdp-config.yaml)
export TDP_BUILDER_IMAGE=$(imgpkg describe -b $(kubectl get -n tap-install $(kubectl get package -n tap-install \
--field-selector spec.refName=tpb.tanzu.vmware.com -o name) -o \
jsonpath="{.spec.template.spec.fetch[0].imgpkgBundle.image}") -o yaml --tty=true | grep -A 1 \
"kbld.carvel.dev/id: harbor-repo.vmware.com/esback/configurator" | grep "image: " | sed 's/\simage: //g')
envsubst < other/resources/tdp/tdp-workload.in.yaml > other/resources/tdp/tdp-workload.yaml
kubectl apply -f other/resources/tdp/tdp-workload.yaml
tanzu kubernetes apps workload tail tdp-configurator --since 64h # wait until a completion shows up with "Build successful"
```

* Update the TDP overlay secret:
```
export TDP_OVERLAY_SECRET=$(kubectl -n default get images.kpack.io tdp-configurator -o jsonpath={.status.latestImage})
envsubst < other/resources/tdp/tdp-overlay-secret.in.yaml > other/resources/tdp/tdp-overlay-secret.yaml
kubectl delete -f other/resources/tdp/tdp-overlay-secret.yaml
kubectl apply -f other/resources/tdp/tdp-overlay-secret.yaml
```

* Uncomment the **package-overlays** section of the TAP values.yaml file, and update tap:
```
source .env
export TAP_1_7_KUBECONFIG_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
export TAP_1_7_KUBECONFIG_CA_B64=$(echo ${TAP_1_7_KUBECONFIG_CA} | base64 --decode)
export TAP_1_7_KUBETOKEN=$(kubectl -n tap-gui get secret tap-gui -o=json | jq -r '.data["token"]' | base64 --decode)
export TAP_1_7_KUBEURL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
#export TAP_1_7_KUBETOKEN=tap-gui
envsubst < resources/tap-values-1.7.in.yaml > resources/tap-values-1.7.yaml
kubectl get pod -l component=backstage-server -ntap-gui -oname | xargs kubectl delete -ntap-gui
tanzu package installed update tap -n tap-install --values-file resources/tap-values-1.7.yaml
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
* Build the workshop image (only required when new workshop files are added):
```
resources/scripts/deploy-image.sh
```
* Follow the instructions to add the desired workshop to your Learning Center as shown:

  | Workshop Name                                  | Link                                                       |
  |------------------------------------------------|------------------------------------------------------------|
  | Tanzu Data with TAP                            | <a href="#workshopa">View Instructions</a>                 |
  | Tanzu Postgres - Kubernetes Deepdive           | <a href="#workshopb">View Instructions</a>                 |
  | Tanzu RabbitMQ - Commercial Features           | <a href="#workshopc">View Instructions</a>                 |
  | Tanzu RabbitMQ - Realtime Analytics Demo       | <a href="#workshopd">View Instructions</a>                 |
  | MLOps with Argo Workflows, MLFlow and TAP      | <a href="#workshope">View Instructions</a>                 |
  | MLOps with Kubeflow Pipelines, MLFlow and TAP  | <a href="#workshopf">View Instructions</a>                 |
  | Machine Learning with Greenplum and TAP        | <a href="#workshopg">View Instructions</a>                 |

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

##### Deploy "MLOps with Argo Workflows, MLFlow and TAP"<a name="workshope"/>
Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-mlops-argo-workflows
  capacity: 10 #Change the capacity to the number of expected participants
  reserved: 1
  expires: 120m
  orphaned: 5m
```

Run the following:
```
resources/scripts/deploy-handson-workshop.sh <path-to-your-env-file>
resources/scripts/workshop-as-a-service/setup-postgres.sh
kubectl delete --all learningcenter-training
kubectl apply -f resources/hands-on/system-profile.yaml
kubectl apply -f resources/workshop-mlops-argo-workflows.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
```

Deploy sample apps:
* git clone git@github.com:agapebondservant/ml-image-processing-app.git
* cd to /ml-image-processing-app
* follow the instructions to **Deploy the Analytics Apps**
* follow the instructions to **Deploy the Training Pipelines**

##### Deploy "MLOps with Kubeflow Pipelines, MLFlow and TAP"<a name="workshopf"/>
Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-mlops-kubeflow-pipelines
  capacity: 10 #Change the capacity to the number of expected participants
  reserved: 1
  expires: 120m
  orphaned: 5m
```

Run the following:
```
resources/scripts/deploy-handson-workshop.sh <path-to-your-env-file>
resources/scripts/workshop-as-a-service/setup-postgres.sh
kubectl delete --all learningcenter-training
kubectl apply -f resources/hands-on/system-profile.yaml
kubectl apply -f resources/workshop-mlops-kubeflow-pipelines.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
```

Deploy sample apps:
* git clone git@github.com:agapebondservant/ml-image-processing-app.git 
* cd to /ml-image-processing-app
* follow the instructions to **Deploy the Analytics Apps**
* follow the instructions to **Deploy the Training Pipelines**

##### Deploy "Machine Learning with Greenplum and TAP"<a name="workshopf"/>
Deploy pre-requisite apps:
* MLflow
* Kubeflow Pipelines
* Datahub
* Argo Workflows (TAP Integration)


Add the following to your `training-portal.yaml` (under **spec.workshops**):
```
- name: data-ml-greenplum-and-tap
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
kubectl apply -f resources/workshop-mlops-greenplum-and-tap.yaml
kubectl apply -f <path-to-your-training-portal.yaml>
watch kubectl get learningcenter-training
```

Deploy sample apps:
* git clone git@github.com:agapebondservant/ml-image-processing-app.git
* cd to /ml-image-processing-app
* follow the instructions to **Deploy the Analytics Apps**
* follow the instructions to **Deploy the Training Pipelines**

#### Create Carvel Packages for Dependencies (not needed for setup)<a name="carvelpackages"/>
* Run the script below:
```

```
  
#### Other: How-tos/General Info (not needed for setup)<a name="other"/>
* For Grafana:
<br/>
RabbitMQ Dashboard: Dashboard ID 10991 
<br/>
Erlang-Distribution Dashboard: Dashboard ID 11352

* To install pgAdmin (helm chart):
```
kubectl create ns pgadmin
helm repo add runix https://helm.runix.net/
helm repo update
helm install pgadmin runix/pgadmin4 --namespace=pgadmin \
--set persistence.storageClass=generic --set strategy.type=Recreate
kubectl apply -f resources/pgadmin.yaml
export PGADMIN_POD_NAME=$(kubectl get pods --namespace pgadmin -l "app.kubernetes.io/name=pgadmin4,app.kubernetes.io/instance=pgadmin" -o jsonpath="{.items[0].metadata.name}")
```

* To install pgAdmin (without helm):
```
Use the pgAdmin accelerator: <a href="https://github.com/agapebondservant/pgadmin-accelerator.git" target="_blank">here</a>

```
To connect to pgAdmin: Connect to your-svc.your-namespace.svc.cluster.local

* To uninstall istio:
```
istio-1.13.2/bin/istioctl x uninstall --purge -y
```

To restart Vault and BuildService after cluster shutdown:
* To reinstall Vault: 
First uninstall:
```
helm uninstall vault -nvault
kubectl delete all --all -nvault
kubectl delete ns vault
```
Then see **Vault** instructions above.

* To reinstall BuildService:
```
tanzu package installed delete buildservice -n tap-install
export BUILD_SVC_VERSION=1.7.4
tanzu package install buildservice -p buildservice.tanzu.vmware.com -v $BUILD_SVC_VERSION -n tap-install -f resources/buildservice.yaml --poll-timeout 30m
export TBS_VERSION=1.9.0
tanzu package repository add tbs-full-deps-repository --url oawofolu/tbs-full-deps:${TBS_VERSION} --namespace tap-install
tanzu package installed delete full-tbs-deps -n tap-install -y
tanzu package install full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v ${TBS_VERSION}  -n tap-install
```
