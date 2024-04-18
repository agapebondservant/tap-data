# populate interpolated variables
[ ! -z "$1" ] && ENV_FILE=$1 || ENV_FILE=.env
resources/scripts/prepare-env.sh $ENV_FILE

# pre-initialize required services
resources/scripts/setup.sh

#  create imagePullSecret, tls secret
kubectl apply -f resources/learning-center-config.yaml
kubectl create secret docker-registry eduk8s-demo-creds --docker-username=$DATA_E2E_REGISTRY_USERNAME --docker-password=$DATA_E2E_REGISTRY_PASSWORD --docker-email=$DATA_E2E_REGISTRY_EMAIL -n learningcenter || true