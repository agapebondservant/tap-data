# DEPLOYING IMAGE ANALYTICS WOTKSHOP

NOTE:
* Currently requires **cluster-admin** privileges to set up.
* Assumes that a Learning Center Portal already exists.

#### Contents
1. [Prepare environment](#prepare-env)
2. [Install Streamlit](#install-streamlit)
3. [Deploy MLFlow](#deploy-mlflow)
5. [Setup Argo Workflows](#setup-argo-workflows)
6. [Setup Spring Cloud Data Flow Pro version](#setup-scdf-pro)
7. [Setup Jupyterflow](#setup-jupyterflow)
8. [Run Methods](#run-methods)

#### Prepare environment <a name="prepare-env"/>
* Set up namespace and secrets:
```
source .env
kubectl create namespace image-analytics || true
kubectl create secret docker-registry pivotal-image-pull-secret --namespace=image-analytics \
  --docker-server=registry.pivotal.io \
  --docker-server=index.docker.io --docker-username="$DATA_E2E_PIVOTAL_REGISTRY_USERNAME" \
  --docker-password="$DATA_E2E_PIVOTAL_REGISTRY_PASSWORD" --dry-run -o yaml | kubectl apply -f -;
kubectl create secret docker-registry image-pull-secret --namespace=image-analytics \
  --docker-username='${DATA_E2E_REGISTRY_USERNAME}' --docker-password='${DATA_E2E_REGISTRY_PASSWORD}' \
  --dry-run -o yaml | kubectl apply -f -
```

#### Install Streamlit <a name="prepare-env"/>
* Install Streamlit:
```
python -m ensurepip --upgrade #on mac
sudo apt-get install python3-pip #on ubuntu 
pip3 install pipenv
xcode-select --install #on mac
softwareupdate --install -a #on mac
```

#### Deploy MLFlow <a name="deploy-mlflow"/>
* Deploy MLFlow: see <a href="https://github.com/agapebondservant/mlflow-demo.git" target="_blank>repository</a>

#### Setup Argo Workflows <a name="setup-argo-workflows"/>
* Setup Argo Events:
```
kubectl create ns argo-events
kubectl apply -f ../argo/amqp-event-source.yaml -n argo-events

```

#### Setup JupyterFlow <a name="setup-jupyterflow"/>
* Install NFS storage class:
```
helm repo add nfs-ganesha-server-and-external-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner/
helm install nfs-release nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner -f ../scdf-pro/nfs-values.yaml
```

* To uninstall NFS (might need to uninstall before reinstalling with new arguments):
```
kubectl delete pvc data-nfs-release-nfs-server-provisioner-0
helm uninstall nfs-release
```

* Setup Jupyterhub Service Account RBAC:
```
kubectl create clusterrolebinding jupyterflow-admin --clusterrole=cluster-admin --serviceaccount=jupyterflow:default
```

* Install Jupyterhub: (**NOTE**: must install the latest version of helm) #TODO: Install via Carvel
```
source ../../../../.env
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace jupyterflow \
  --create-namespace \
  --values ../jupyterhub/jupyterhub-config.yaml
envsubst < ../jupyterhub/jupyterhub-http-proxy.in.yaml > ../jupyterhub/jupyterhub-http-proxy.yaml
kubectl apply -f ../jupyterhub/jupyterhub-http-proxy.yaml -njupyterflow
Navigate to http://$(kubectl get svc proxy-public -njupyterflow -o jsonpath='{.status.loadBalancer.ingress[0].hostname})
Login with username/password: jupyter/jupyter
```

* Install Argo Workflows:
```
source ../../../../.env
kubectl apply -f ../argo/argo-workflow.yaml -njupyterflow
envsubst < ../argo/argo-workflow-http-proxy.in.yaml > ../argo/argo-workflow-http-proxy.yaml
kubectl patch svc argo-server -p '{"spec": {"type": "LoadBalancer"}}' -n jupyterflow
kubectl patch configmap workflow-controller-configmap --patch '{"data":{"containerRuntimeExecutor":"pns"}}' -njupyterflow
kubectl scale deploy argo-server --replicas 1 -njupyterflow && kubectl scale deploy workflow-controller --replicas 1 -njupyterflow
kubectl apply ../argo/argo-workflow-http-proxy.yaml
watch kubectl get po -njupyterflow
Navigate to https://argo-workflows.<your-domain-name>
```

#### Run Methods

* Launch UI locally:
```
pipenv shell
pip install -r requirements-dev.txt
RAY_ADDRESS=<your Ray address> python -m streamlit run app/ui/main.py --logger.level=info model_stage=None
```

### Build Docker Containers for Apps
```
docker build -t oawofolu/image-analytics .
docker push oawofolu/image-analytics
```

### Deploy Apps to Kubernetes
* Deploy apps:
```
kubectl create deployment image-analytics-dev --image=oawofolu/image-analytics  -nimage-analytics -- streamlit run app/ui/home.py --model_stage=None
kubectl create deployment image-analytics-prod --image=oawofolu/image-analytics  -nimage-analytics -- streamlit run app/ui/home.py --model_stage=Production
kubectl expose deployment image-analytics-dev --port=8080 --target-port=8501 --name=image-analytics-dev-svc --type=LoadBalancer -nimage-analytics
kubectl expose deployment image-analytics-prod --port=8080 --target-port=8501 --name=image-analytics-prod-svc --type=LoadBalancer -nimage-analytics
watch kubectl get all -nimage-analytics
# (NOTE: If on AWS, change the timeout settings for the LoadBalancers to 3600)
# (NOTE: Update any associated DNS entries as appropriate)
```
