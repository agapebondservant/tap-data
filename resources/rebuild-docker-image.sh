# populate interpolated variables
[ ! -z "$1" ] && ENV_FILE=$1 || ENV_FILE=.env
source "$ENV_FILE"
for orig in `find $(pwd) -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
  grep $target .gitignore || echo $target >> .gitignore
  git rm --cached -q $target > /dev/null 2>&1
done

# pre-initialize required services
resources/setup.sh

# rebuild workshop images
DATA_E2E_WORKSHOP_IMAGE_VERSION=`date "+%Y%m%d.%H%M"`
echo "Building version...$DATA_E2E_WORKSHOP_IMAGE_VERSION"
echo $DATA_E2E_REGISTRY_PASSWORD | docker login --username=oawofolu --password-stdin
tar -xzvf other/resources/helm*.tar.gz -C other/resources && \
    chmod +x other/resources/linux-amd64/helm && \
    tar -zvxf other/resources/k9s*.tar.gz -C other/resources && \
    chmod +x other/resources/k9s && \
    mv other/resources/k9s other/resources/bin/k9s &&
    chmod +x other/resources/bin/imgpkg && \
    mv other/resources/linux-amd64/helm other/resources/bin/helm &&
    chmod +x workshop/terminal/*.sh

docker build -t $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION --build-arg BASE_IMAGE=oawofolu/learning-platform-image:v1 .
docker tag $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION $DATA_E2E_REGISTRY_URL
docker push $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION
docker push $DATA_E2E_REGISTRY_URL
#  create imagePullSecret
kubectl create secret docker-registry eduk8s-demo-creds --docker-username=$DATA_E2E_REGISTRY_USERNAME --docker-password=$DATA_E2E_REGISTRY_PASSWORD --docker-email=$DATA_E2E_REGISTRY_EMAIL -n learningcenter || true
