# populate interpolated variables
resources/scripts/prepare-env.sh

# pre-initialize required services
resources/scripts/setup.sh

#  create imagePullSecret, tls secret
kubectl apply -f resources/learning-center-config.yaml
kubectl create secret docker-registry eduk8s-demo-creds --docker-username=$DATA_E2E_REGISTRY_USERNAME --docker-password=$DATA_E2E_REGISTRY_PASSWORD --docker-email=$DATA_E2E_REGISTRY_EMAIL -n learningcenter || true

# redeploy workshop
kubectl delete --all learningcenter-training
kubectl apply -k .
watch kubectl get learningcenter-training