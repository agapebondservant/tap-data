### Deploying ML Pipeline

![MLOps - Experimentation](images/mlops-usecase-mlpipeline-kubeflow.jpg)

After **packaging** and **containerizing** our ML model code, we will need to setup an **ML pipeline** to handle its orchestration.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    The template for the Kubeflow Pipelines deployment was taken from an <b>Accelerator</b>.
    To view, go to the Accelerators page and search for <b>kubeflow</b>.
</div>
<div style="clear: left;"></div>

For this, we will use **Kubeflow Pipelines**. **Kubeflow Pipelines** comes from the popular MLOps toolset **Kubeflow**, which 
is a broad suite that consists of various components: native Jupyter Notebook integration, 
model serving, native integration with popular ML frameworks like Tensorflow/Keras, 
extensive add-on support like Elyra for UI-based pipeline design and Kale for extending JupyterLab notebooks, etc.
In this case, we will only be using **Kubeflow Pipelines** , which is the pipeline orchestration component.
Also, it is backed by the popular workflow orchestrator **Argo Workflows**, whose backend - **ArgoCD** - has built-in support in **TAP**.

(<font color="red">NOTE:</font> Learn more about Kubeflow Pipelines here: <a href="https://www.kubeflow.org/docs/components/pipelines/v1/introduction/" target="_blank">Kubeflow Pipelines</a>)

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    <b>Why should we use a pipeline orchestrator?</b><br/>
    By decoupling the pipeline from its orchestration, it is easier to perform management tasks like retries and rollbacks.
    Orchestration also helps with standardizing pipeline deployment for reuse/repeatability, 
    and decoupling pipeline steps for greater flexibility and integration: for example, it provides the ability 
    to leverage multiple languages and frameworks in the same pipeline.
</div>
<div style="clear: left;"></div>

Similarly to how we deployed **MLflow**, we will deploy **Kubeflow Pipelines** on **TAP** using the **tanzu** cli.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    Deploying the ML pipelines is usually the responsibility of the <b>ML engineer</b>.
    A data scientist shouldn't have to worry about this task unless (s)he wears multiple hats on the project, 
    or needs access to an ML pipeline orchestrator via <b>self-service provisioning</b>.
</div>
<div style="clear: left;"></div>

Let's search for the package from the list of installed packages:
```execute
tanzu package installed list -n mlops-tools | grep kubeflow-pipelines
```

It shows that **Kubeflow Pipelines** has already been installed for us on **TAP** - we can see it in the TAP GUI:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```


Access Kubeflow Pipelines by retrieving the URL via the **tanzu cli**:
```execute
tanzu apps workloaad get kubeflow-pipelines-tap
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

To kick off pipeline orchestration for our ML pipeline, let's deploy the App CR:
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


