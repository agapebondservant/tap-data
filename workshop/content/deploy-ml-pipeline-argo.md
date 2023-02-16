### Deploying ML Pipeline

![MLOps - Experimentation](images/mlflow-usecase-mlpipeline-argo.jpg)

After **packaging** and **containerizing** our ML model code, we will need to setup an **ML pipeline** to handle its orchestration.

For this, we will use **Argo Workflows**. **Argo Workflows** is backed by the popular GitOps engine **ArgoCD**, which has built-in support in **TAP**.

(<font color="red">NOTE:</font> Learn more about Argo Workflows here: <a href="https://argoproj.github.io/argo-workflows/" target="_blank">Argo Workflows</a>)

Let's access the web UI:
```dashboard:create-dashboard
name: Argo
url: https://argo-workflows.{{ ingress_domain }}
```

<font color="red">NOTE:</font> Get the access token here:
```execute
clear; kubectl -n argo exec $(kubectl get pod -n argo -l 'app=argo-server' -o jsonpath='{.items[0].metadata.name}') -- argo auth token
```

Let's view the manifest for our Argo Workflow:
```editor:open-file
file: ~/other/resources/argo-workflows/pipeline.yaml
```

We can see that the workflow comprises of *4* steps - 
**upload_dataset**, **train-model**, **evaluate-model** and **promote-model-to-staging** -
with a set of **parameters** for each step.

In keeping with our MLDevOps approach, we would like our pipeline deployment to be as automated as possible.
With **TAP**, using a **GitOps**-ready deployment approach is easy. There are many supported flavors.
One of the simplest is to use the **AppCR** resource, which is backed by Carvel's **kapp-controller**.
With AppCR, we can use a lightweight approach to employ a declarative, Infrastructure-as-Code deployment,
allowing us to use our git repository as the source of truth that takes care of synching up our latest changes with our environment.

(<font color="red">NOTE:</font> Learn more about App CR here: <a href="https://carvel.dev/kapp-controller/docs/v0.38.0/app-overview/" target="_blank">Argo Workflows</a>)

Let's view the manifest for our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_main.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.)

Let's copy the App CR and pipeline files to our ML code directory:
```execute
cp ~/other/resources/appcr/pipeline_app_main.yaml ~/sample-ml-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_main.yaml ~/sample-ml-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline.yaml ~/sample-ml-app/pipeline.yaml
```

Our directory now looks like this:
```execute
ls -ltr ~/sample-ml-app
```

Let's deploy the App CR:
```execute
kapp deploy -a image-procesor-pipeline-{{session_namespace}} -f ~/sample-ml-app/pipeline_app.yaml --logs -y  -n{{session_namespace}}
```

Our newly deployed pipeline should now be visible. 
```dashboard:reload-dashboard
name: Argo
url: https://argo-workflows.{{ ingress_domain }}
```

In a few minutes, we should be able to access a newly trained ML model in MlFlow. 
Let's proceed to see what that looks like.










