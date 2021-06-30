### Deploying Data E2E Workshop (AWS)

- NOTE: eduk8s version used: 20.12.03.1 
(201203.030350.f72ecda)


####Kubernetes Cluster Pre-reqs
- Create new cluster for Educates platform: tkg create cluster educates-cluster --plan=devharbor -w 3

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

~~~~~~OR~~~~~~~~~~~~~~~~
chmod +x resources/deploy-worshop.sh
resources/deploy-workshop.sh

- Deploy workshop:
kubectl apply -k .

