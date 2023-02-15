### Deploying JupyterHub

Before we begin, we need to be able to perform **experiments** that will help us to understand how to build an optimized model for our problem statement.

![MLOps - Experimentation](images/mlflow-usecase-experimentation.jpg)

This is an **iterative** process and requires the ability to perform **rapid model development**, **track** and **audit** experiment runs,
and **collaborate** and **share** results with the team.

**JupyterHub** is a popular tool that data scientists use for this purpose.
It is used for hosting **Jupyter notebooks**.
A **Jupyter notebook** provides a browser-based IDE that enables live coding, experimentation, data exploration and model engineering.
**JupyterHub** is a containerized, open-source app, making it easy to deploy on **TAP**.

Let's begin!

#### How to deploy

The simplest way to deploy apps on **TAP** is by using the **tanzu cli**.
This allows **TAP** to use a single-line install to deploy apps that have been previously packaged as **Carvel Packages**.
**TAP** comes with a number of pre-installed Packages, and supports the ability to discover and add new Packages.
Any containerized app can be transformed into a **Carvel Package**, with an associated source repository called a **PackageRepository**,
making it ready to install on **TAP**.

First, let's take a look at the JupyterHub Package Repository that we wish to install:
```dashboard:open-url
url: https://hub.docker.com/r/{{DATA_E2E_REGISTRY_USERNAME}}/jupyter-package-repo
```

We will reference the path to the registry for the install as our _url_ parameter.

Let's go ahead and install the JupyterHub Package Repository:
```execute
echo {{ DATA_E2E_REGISTRY_PASSWORD }} | docker login registry-1.docker.io --username={{ DATA_E2E_REGISTRY_USERNAME }} --password-stdin; cd ~ && tanzu init && tanzu plugin install --local bin/cli secret && tanzu secret registry delete regsecret --namespace default -y || true; tanzu secret registry add regsecret --username {{ DATA_E2E_REGISTRY_USERNAME }} --password {{ DATA_E2E_REGISTRY_PASSWORD }} --server {{ DATA_E2E_REGISTRY_USERNAME }} --export-to-all-namespaces --yes --namespace default; tanzu package repository add jupyterhub-package-repository --url {{DATA_E2E_REGISTRY_USERNAME}}/jupyter-package-repo:{{DATA_E2E_JUPYTERHUB_VERSION}}
```

Next, let's verify that the Jupyterhub package is now available:
```execute
tanzu package available list jupyter.tanzu.vmware.com
```

As a next step, we may want to update the default configuration values associated with the Jupyterhub package.
To do this, let's view our options by showing the **values schema**:
```execute
tanzu package available get jupyter.tanzu.vmware.com/{{DATA_E2E_JUPYTERHUB_VERSION}} --values-schema
```

In our case, we'd like to update a few of the properties shown. 
We do this be preparing a **values.yaml** file with the schema properties we want to update.
Let's generate the file:
```execute
cat > ~/other/resources/jupyterhub/jupyter-values.yaml <<- EOF
namespace: {{ session_namespace }}
image: {{DATA_E2E_REGISTRY_USERNAME}}/jupyter-package-repo:{{DATA_E2E_JUPYTERHUB_VERSION}}
version: {{DATA_E2E_JUPYTERHUB_VERSION}}
base_domain: {{DATA_E2E_BASE_URL}}
container_repo_user: {{DATA_E2E_REGISTRY_USERNAME}}
EOF
```

Now we can proceed to install the package:
```execute
tanzu package install jupyterhub -p jupyter.tanzu.vmware.com -v {{DATA_E2E_JUPYTERHUB_VERSION}} --values-file ~/other/resources/jupyterhub/jupyter-values.yaml
```

Verify that the install was successful:
```execute
tanzu package installed get jupyterhub
```

Next, we view it (login with the default username and password shown above - jupyter/jupyter123):
```dashboard:create-dashboard
name: JupyterHub2
url: {{ ingress_protocol }}://jupyter-{{session_namespace}}.{{ ingress_domain }}
```

We also need to be able to track our experiments, including properties like metrics and artifacts.
In addition, we want to be able to store our models in some kind of Model Registry.
For this and more, we will need to leverage an **MLOps** framework.
We will deploy this next.




