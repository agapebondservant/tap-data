### Deploying ML Pipeline

![MLOps - Experimentation](images/mlops-usecase-mlpipeline-kubeflow.jpg)

After **packaging** and **containerizing** our ML model code, we will need to setup an **ML pipeline** to handle its orchestration.

For this, we will use **Kubeflow Pipelines**. **Kubeflow Pipelines** comes from the popular MLOps toolset **Kubeflow**, which 
is a broad suite that consists of various components: native Jupyter Notebook integration, 
model serving, native integration with popular ML frameworks like Tensorflow/Keras, 
extensive add-on support like Elyra for UI-based pipeline design and Kale for extending JupyterLab notebooks, etc.
In this case, we will only be using **Kubeflow Pipelines** , which is the pipeline orchestration component.
Also, it is backed by the popular workflow orchestrator **Argo Workflows**, whose backend - **ArgoCD** - has built-in support in **TAP**.

(<font color="red">NOTE:</font> Learn more about Kubeflow Pipelines here: <a href="https://www.kubeflow.org/docs/components/pipelines/v1/introduction/" target="_blank">Argo Workflows</a>)

Similarly to how we deployed **MLflow**, we will deploy **Kubeflow Pipelines** on **TAP** using the **tanzu** cli.
Let's try it - first, we install the Kubeflow Package Repository:
```execute
clear; export KUBEFLOW_PACKAGE_VERSION=0.0.1; tanzu package repository add kubeflow-pipelines --url ghcr.io/agapebondservant/kubeflow-pipelines:$KUBEFLOW_PACKAGE_VERSION -n {{session_namespace}}
```

Next, we may want to update the default configuration values associated with the Kubeflow package.
To do this, let's view our options by showing the **values schema**:
```execute
clear; tanzu package available get kubeflow-pipelines.tanzu.vmware.com/${KUBEFLOW_PACKAGE_VERSION} --values-schema -n {{session_namespace}}
```

In our case, we'd like to update the properties shown.
We'll use this script to generate our **values.yaml** file:
```execute
cat > ~/other/resources/kubeflow/kubeflow-values.yaml <<- EOF
full_url: kubeflow-pipelines-{{session_namespace}}.{{ ingress_domain }}
EOF
```

Here's the final **values.yaml** file:
```editor:open-file
file: ~/other/resources/kubeflow/kubeflow-values.yaml
```

Now we can proceed to install the package:
```execute
tanzu package install kubeflow-pipelines --package-name kubeflow-pipelines.tanzu.vmware.com --version $KUBEFLOW_PACKAGE_VERSION --values-file ~/other/resources/kubeflow/kubeflow-values.yaml -n {{session_namespace}}
```
(<font color="red">NOTE:</font> The output currently includes an error which can be ignored.)

With that, you should be able to access Kubeflow Pipelines:
```dashboard:create-dashboard
name: Kubeflow
url: {{ ingress_protocol }}://kubeflow-pipelines-{{ session_namespace }}.{{ ingress_domain }}
```

Next, let's fetch the source code for our Kubeflow Pipeline:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}} && export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-kubeflow-pipeline.git ~/sample-kubeflow-pipeline
```

Let's view the code:
```editor:open-file
file: ~/sample-kubeflow-pipeline/app/main.py
```

We can see that the workflow comprises of *4* steps -
**upload_dataset**, **train-model**, **evaluate-model** and **promote-model-to-staging** -
with a set of **parameters** for each step.

We need to package this code as a task which will execute in a declarative, repeatable way.
For this, we will use **Knative Services** to launch a serverless runtime environment which will run our task. 
**Knative Services** have built-in support in TAP through the **Cloud Native Runtimes** component.
```editor:open-file
file: ~/other/resources/knative/kfp-pipeline.yaml
```
(<font color="red">NOTE:</font> Learn more about Cloud Native Runtimes here: <a href="https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/2.1/tanzu-cloud-native-runtimes/cnr-overview.html" target="_blank">Cloud Native Runtimes</a>)

In keeping with our MLDevOps approach, we would like our pipeline deployment to be as automated as possible.
With **TAP**, using a **GitOps**-ready deployment approach is easy. There are many supported flavors.
One of the simplest is to use the **AppCR** resource, which is backed by Carvel's **kapp-controller**.
With AppCR, we can use a lightweight approach to employ a declarative, Infrastructure-as-Code deployment,
allowing us to use our git repository as the source of truth that takes care of synching up our latest changes with our environment.

(<font color="red">NOTE:</font> Learn more about App CR here: <a href="https://carvel.dev/kapp-controller/docs/v0.38.0/app-overview/" target="_blank">Argo Workflows</a>)

Let's view the manifest for our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_kfp.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.)

Let's copy the App CR and pipeline files to our ML code directory:
```execute
cp ~/other/resources/appcr/pipeline_app_kfp.yaml ~/sample-kubeflow-pipeline/pipeline_app.yaml && cp ~/other/resources/appcr/values_kfp.yaml ~/sample-kubeflow-pipeline/values.yaml && cp ~/other/resources/knative/kfp-pipeline.yaml ~/sample-kubeflow-pipeline/pipeline.yaml
```

Our directory now looks like this:
```execute
ls -ltr ~/sample-ml-app
```

Let's deploy the App CR:
```execute
kapp deploy -a image-procesor-pipeline-kfp-{{session_namespace}} -f ~/sample-kubeflow-pipeline/pipeline_app.yaml --logs -y  -n{{session_namespace}}
```

Our newly deployed pipeline should now be visible.
```dashboard:reload-dashboard
name: Kubeflow
url: {{ ingress_protocol }}://kubeflow-pipelines-{{ session_namespace }}.{{ ingress_domain }}
```

Training a CNN model can take a while.
In a few minutes, we should be able to access a newly trained ML model in MlFlow.
Let's proceed to see what that looks like.


