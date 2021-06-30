
# rebuild workshop image
echo "Enter the build version:"
read MY_WORKSHOP_IMAGE_VERSION
source workshop/profile
echo $MY_REGISTRY_PASSWORD | docker login --username=oawofolu --password-stdin
tar -xzvf other/resources/helm*.tar.gz -C other/resources && \
    chmod +x other/resources/linux-amd64/helm && \
    tar -zvxf other/resources/k9s*.tar.gz -C other/resources && \
    chmod +x other/resources/k9s && \
    mv other/resources/k9s other/resources/bin/k9s &&
    mv other/resources/linux-amd64/helm other/resources/bin/helm &&
    chmod +x workshop/terminal/*.sh
docker build -t $MY_REGISTRY_URL:$MY_WORKSHOP_IMAGE_VERSION .
docker tag $MY_REGISTRY_URL:$MY_WORKSHOP_IMAGE_VERSION $MY_REGISTRY_URL
docker push $MY_REGISTRY_URL:$MY_WORKSHOP_IMAGE_VERSION
docker push $MY_REGISTRY_URL
#  create imagePullSecret
kubectl create secret docker-registry eduk8s-demo-creds --docker-username=$MY_REGISTRY_USERNAME --docker-password=$MY_REGISTRY_PASSWORD --docker-email=$MY_REGISTRY_EMAIL -n eduk8s || true
# redeploy workshop
kubectl delete --all eduk8s-training; kubectl apply -k .; watch kubectl get eduk8s-training