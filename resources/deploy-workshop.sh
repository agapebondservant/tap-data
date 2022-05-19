# rebuild docker image
ENV_FILE=$1 || .env
resources/rebuild-docker-image.sh $ENV_FILE
# redeploy workshop
kubectl delete --all learningcenter-training
kubectl apply -k .
watch kubectl get learningcenter-training
