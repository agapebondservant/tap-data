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
    chmod +x workshop/terminal/*.sh &&
    chmod +x other/resources/bin/kbld &&
    chmod +x other/resources/bin/kapp

docker build -t $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION --build-arg BASE_IMAGE=oawofolu/learning-platform-image:v1 .
docker tag $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION $DATA_E2E_REGISTRY_URL
docker push $DATA_E2E_REGISTRY_URL:$DATA_E2E_WORKSHOP_IMAGE_VERSION
docker push $DATA_E2E_REGISTRY_URL
