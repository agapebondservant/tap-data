### Deploying Data E2E Workshop (AWS)

- NOTE: eduk8s version used: 20.12.03.1 
(201203.030350.f72ecda)


####Kubernetes Cluster Pre-reqs
- Create new cluster for Educates platform: tkg create cluster educates-cluster --plan=devharbor -w 6

- Create the default storage class (ensure that it is called generic, that the volume binding mode is WaitForFirstCustomer instead of Immediate, and the reclaimPolicy should be Retain) - storage-class-aws.yml

- Mark the storage class as default: kubectl patch storageclass generic -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

- Create the network policy (network-policy-yml - uses allow-all-ingress for now)

- Install Contour: https://bitnami.com/stack/contour/helm

- Install Educates Operator: kubectl apply -k https://github.com/eduk8s/eduk8s.git?ref=20.12.03.1

- Verify installation: kubectl get all -n eduk8s

- Specify ingress domain: kubectl set env deployment/eduk8s-operator -n eduk8s INGRESS_DOMAIN=tanzudata.ml

- If using applications with websocket connections, increase idle timeout on ELB in AWS Management Console to 1 hour (default is 30 seconds)

- Ensure that pod scurity policy admission controller is enabled, as PSPs will be created by the eduk8s operator to restrict users from running with root privileges:
kube-apiserver --enable-admission-plugins PodSecurityPolicy

- Deploy cluster-scoped cert-manager:
kubectl create ns cert-manager
kubectl apply -f resources/cert-manager.yaml
Deploy CERT-MANAGER-ISSUER  (self-signed), CERTIFICATE-SIGNING-REQUEST, CERT-MANAGER-ISSUER (CA) (from resources/cert-manager-issuer.yaml)
    
- Build workshop image:
echo $MY_REGISTRY_PASSWORD | docker login --username=oawofolu --password-stdin
chmod +x other/resources/kubectl &&
    tar -xzvf other/resources/helm*.tar.gz -C other/resources && \
    chmod +x other/resources/linux-amd64/helm && \
    tar -zvxf other/resources/k9s*.tar.gz -C other/resources && \
    chmod +x other/resources/k9s &&
    chmod +x workshop/profile #TODO: figure out how to add this to the Dockerfile
docker build -t (the registry url):0.1 .
ddocker tag (the registry url):0.1 (the registry url)
docker push (the registry url):0.1
docker push (the registry url)
MY_REGISTRY_USERNAME=(the username) MY_REGISTRY_PASSWORD=(the password) MY_REGISTRY_EMAIL=(the email) kubectl create secret docker-registry eduk8s-demo-creds --docker-username=$MY_REGISTRY_USERNAME --docker-password=$MY_REGISTRY_PASSWORD --docker-email=$MY_REGISTRY_EMAIL -n eduk8s

- Label a subset of the nodes (for which anti-affinity/affinity rules will apply):
a=0
for n in $(kubectl get nodes --selector='!node-role.kubernetes.io/master' --output=jsonpath={.items..metadata.name}); do
    if [ $a -eq 0 ]; then kubectl label node $n gpdb-worker=master; fi; 
    if [ $a -eq 1 ]; then kubectl label node $n gpdb-worker=segment; fi; 
    a=$((a+1)) 
done

~~~~~~OR~~~~~~~~~~~~~~~~
chmod +x resources/deploy-worshop.sh
resources/deploy-workshop.sh

- Deploy workshop:
kubectl apply -k .

- Deploy Minio (Server):
(LEGACY APPROACH:)
helm repo add minio-legacy https://helm.min.io/
helm install --namespace minio --generate-name minio/minio
kubectl create ns minio
helm install --namespace minio --generate-name minio-legacy/minio
export MINIO_ACCESS_KEY=$(kubectl get secret minio-1626071207 -o jsonpath="{.data.accesskey}" -n minio| base64 --decode)
export MINIO_SECRET_KEY=$(kubectl get secret minio-1626071207 -o jsonpath="{.data.secretkey}" -n minio| base64 --decode)
export MINIO_POD_NAME=$(kubectl get pods --namespace minio -l "release=minio-1626071207" -o jsonpath="{.items[0].metadata.name}")
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

- Deploy Greenplum:
source .env
envsubst < resources/setup.sh.in > resources/setup.sh
./setup.sh
