### Rapid-fire Demo

#### Launch app from TAP GUI
View the app in TAP GUI:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/supply-chain
```

Launch the app by clicking on the URL from the **tanzu** cli:
```execute
tanzu apps workload get image-processor --namespace default
```

Upload an image and observe that the app is waiting for the model to be available.
This requires a viable model to be promoted to the "Production" stage.

To view the model registry, launch MLflow and click on the "Models" tab:
```dashboard:open-url
url: http://mlflow.{{ ingress_domain }}
```

#### Launch Jupyter Notebook
We will use TAP to discover the **tooling** that we will need for our development environment.

Click on the Jupyter tab in the workshop (**jupyter** as the password), and show the **File Ingestion** notebook.

This is the Jupyter notebook that was used to create experiments for our training use case. 
To migrate it to our own self-managed instance of Jupyterhub, we will self-provision Jupyterhub using **TAP**.

#### Option A: Launch Jupyter Notebook via Kubeapps
<font color="red"><b>In progress - skip to "Option B: Launch Jupyter Notebook via tanzu cli".</b></font><br/>
**Kubeapps** provides a web-based GUI for deploying and managing applications to Kubernetes.
Currently, **Kubeapps** supports applications that are packaged as **helm charts** or **Carvel packages**.
(**Carvel packages** have the advantage of greater interoperability with a broad set of Kubernetes packaging formats 
- including Helm - and sources, 
and are automatically synced via Carvel's **kappcontroller**, which enables more declarative package management.)

Here, we will show how to use it to deploy a JupyterHub Carvel package.

Launch **Kubeapps** using the URL provided here:
```execute
export KUBEAPPS_SERVICE_IP=$(kubectl get svc --namespace {{session_namespace}} kubeapps -o jsonpath="{.status.loadBalancer.ingress[0].hostname}");
echo "http://${KUBEAPPS_SERVICE_IP}"
```

Use the token generated below to login:
```execute
kubectl delete serviceaccount kubeappuser -n {{session_namespace}} || true; 
kubectl create -n {{session_namespace}} serviceaccount kubeappuser;
kubectl delete clusterrolebinding kubeappuser{{session_namespace}}binding || true; 
kubectl create clusterrolebinding kubeappuser{{session_namespace}}binding --clusterrole=cluster-admin --serviceaccount={{session_namespace}}:kubeappuser;
export KUBEAPPS_SERVICE_IP_TOKEN=$(kubectl create token kubeappuser -n {{session_namespace}});
```

In the top right, select the dropdown under **Current Context**, copy the text below to the **Namespace** dropdown, and click "Change Context":
```copy
{{session_namespace}}
```

Next, go to the **Catalog** tab, click **AI** checkbox (under "Categories" on the left), 
click on "Jupyterhub on Tanzu",
and click "Deploy". 
The Visual Editor screen should show up: enter "jupyter-test" for "name", "default" for "Service Account", and
change **base_domain** to the value below, then click "Deploy":
```copy
{{ ingress_domain }}
```
This should trigger deployment of the Jupyterhub app (view the pods below).


#### Option B: Launch Jupyter Notebook via tanzu cli
View the Jupyter accelerator in TAP GUI (search for **ml** first, just to demonstrate how accelerators can be used, then search for **jupyter**):
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```

Verify that the Jupyterhub package is available:
```execute
tanzu package available list jupyter.tanzu.vmware.com -n {{session_namespace}}
```

View the install configuration options by showing the **values schema**:
```execute
tanzu package available get jupyter.tanzu.vmware.com/{{DATA_E2E_JUPYTERHUB_VERSION}} --values-schema -n {{session_namespace}}
```

View the values.yaml file based on the configuration options:
```editor:open-file
file: ~/other/resources/jupyterhub/jupyter-values.yaml
```

Install the package:
```execute
tanzu package install jupyterhub -p jupyter.tanzu.vmware.com -v {{DATA_E2E_JUPYTERHUB_VERSION}} --values-file ~/other/resources/jupyterhub/jupyter-values.yaml -n {{session_namespace}}
```

View the installed package (login with the default username and password used above - jupyter/Vmware1!):
```dashboard:open-url
url: {{ ingress_protocol }}://jupyter-{{session_namespace}}.{{ ingress_domain }}
```

#### Launch Catalog
<font color="red"><b>NOTE: For a high-level demo, this section may be skipped as optional.</b></font><br/>

In order to begin, we will need to discover a suitable **data source** that can provide CIFAR-10 data for our object detection experiments.
This is a part of the **Discovery** phase.

We will use a **Data Catalog** for this. A **Data Catalog** is a data discovery tool that uses metadata management to ensure data quality.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>Why is a data catalog necessary?</b><br/>
    Effective ML starts with the <b>quality of data</b>. This concept is known as the "Unreasonable Effectiveness of Data". 
    Time and time again, it has been shown that data quality - based on size, variability, staleness etc - is much more important to 
    the performance of the model than the actual model itself. 
    Hence, we need a way to discover and curate quality <b>data sets</b> for our models. 
    Quality data requires quality metadata, so we will need a <b>metadata management</b> platform to enforce data quality.
</div>
<div style="clear: left;"></div>

With **Tanzu Application Platform**, we have **unrestricted flexibility** for selecting a data catalog.
We can use a prebundled Carvel package, or we can **bring our own data catalog** as long as it is containerized.
For the purposes of this exercise, we will be using **DataHub** as our data catalog.

From **TAP GUI**, go to the **Worklooads** screen:
```dashboard:open-url
url: http://tap-gui.{{ ingress_domain }}/supply-chain
```

Click on the DataHub workload (it should show up as **datahub-tap**.) Notice that the app is in *Ready** state.

Launch DataHub by clicking on the URL from the **tanzu** cli:
```execute
tanzu apps workload get datahub-tap --namespace default
```

Login to **DataHub** (credentials: **datahub/datahub**), and click on the DataHub icon (top-left).

Next, enter **"data lake"** in the Search Bar (include the double quotes), and select the Tag in the dropdown that displays.
The results should show that the **"data lake"** tag was applied to 1 Dataset; click on that link.

Click on the asset that displays in the results (it should be a parquet file).
It has been previously tagged in DataHub as a **Data Lake** asset. This data source contains the data that will be used for our experiments.
Click on the "Properties" tab to view more detail.

#### Launch Pipeline
View Argo Workflows in the TAP GUI - the Argo Workflows app should be visible:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/supply-chain
```

View Kubeflow Pipelines as well:
```dashboard:open-url
url: {{ ingress_protocol }}://kubeflow-pipelines.{{ ingress_domain }}
```

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    Argo Workflows is more general-purpose, including support for triggers from many different sources - message queues, web hooks, S3 buckets, etc.\
</div>

Launch Argo Workflows by retrieving the URL from the **tanzu cli** (you may need to click on the topmost menu tab on the left to see the initial screen):
```execute
tanzu apps workload get argoworkflows-tap --namespace default
```

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    <b>Why should we use a pipeline orchestrator?</b><br/>
    By decoupling the pipeline from its orchestration, it is easier to perform management tasks like retries and rollbacks.
    Orchestration also helps with standardizing pipeline deployment for reuse/repeatability, 
    and decoupling pipeline steps for greater flexibility and integration: for example, it provides the ability 
    to leverage multiple languages and frameworks in the same pipeline.
</div>

<font color="red">NOTE:</font> Copy the access token from here to the Login box:
```execute
clear; kubectl -n argo exec $(kubectl get pod -n argo -l 'app=argo-server' -o jsonpath='{.items[0].metadata.name}') -- argo auth token
```

In keeping with our MLDevOps approach, we would like our pipeline deployment to be as automated as possible.
With **TAP**, using a **GitOps**-ready deployment approach is easy. There are many supported flavors.
One of the simplest is to use the **AppCR** resource, which is backed by Carvel's **kapp-controller**.
With AppCR, we can use a lightweight approach to employ a declarative, Infrastructure-as-Code deployment,
allowing us to use our git repository as the source of truth that takes care of synching up our latest changes with our environment.

Fetch the code:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}};
export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && rm -rf ~/sample-ml-app;
git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git -b main-{{session_namespace}} ~/sample-ml-app;
```

Let's view the manifest that was used to enable **GitOps**-ready deployment by viewing our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_main.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.)

Update the training parameters for this workflow (under **train_model** --> **parameters**, increase **epochs** from 10 to 15):
```editor:open-file
file: ~/sample-ml-app/MLproject
```

Commit to Git:
```execute
cp ~/other/resources/appcr/pipeline_app_main.yaml ~/sample-ml-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_main.yaml ~/sample-ml-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline.yaml ~/sample-ml-app/pipeline.yaml;
cd ~/sample-ml-app; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git add .; git commit -m 'New commit'; git push origin main-{{session_namespace}}; cd -; kapp deploy -a image-procesor-pipeline-{{session_namespace}} -f ~/sample-ml-app/pipeline_app.yaml --logs -y  -n{{session_namespace}}
```

Our newly deployed workflow should now be visible.
```dashboard:open-url
url: https://argo-workflows.{{ ingress_domain }}
```

The newly created experiment should also be visible in MlFlow:
```dashboard:open-url
url: http://mlflow.{{ ingress_domain }}
```

#### Launch In-Database Pipeline
As our models begin to scale out in size and/or complexity, we will find that we need to be able to scale our training environment.
There are many different approaches for scaling an ML environment.
One popular approach is to use separate clusters for **training** and **inference**.
**Training** is done on a highly parallelized cluster that is colocated where the **data** resides, while
**inference** occurs on a separate cluster that is colocated where the **apps/consumers** reside.

In this session, we will use **in-database analytics** to move the training compute where the **data** resides.
This way, our training pipelines will actually run within the database itself.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    Also, in-database analytics often includes native support for queries that can be challenging to achieve in a distributed environment,
    such as distributed joins, sorts, aggregations and parallelization.
</div>
<div style="clear: left;"></div>

**Tanzu Application Platform** can easily integrate with just about any modern database using **Service Bindings**.
This includes databases with support for **in-database analytics**.
In this exercise, we will use **VMware Greenplum** for in-database analytics.

Let's go back to our datasets from the data catalog:
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

Login (credentials: **datahub/datahub**), go to the Home Page (click on the top-left icon),
click on the "Explore all" link and select **ServiceBinding Sources**
in the **View** search bar towards the top (with the prompt text "Create a View").

These are the assets that have been previously tagged as **ServiceBinding** resources.
**ServiceBindings** is a Kubernetes-standard specification for connecting apps with databases, API services and
other resources, and it is supported out of the box by **TAP**. More on **ServiceBindings** will be explored later in the session.

The results should include 1 **greenplum** database and 1 **postgres** database. Click on each link and explore each asset.

Notice the following:
* The **greenplum** database has been tagged as a **training** asset. This is the dataset that will be used for **training**.
* The **postgres** database has been tagged as an **inference** asset. This is the dataset that will be used for **inference**.
* The Greenplum instance is tagged as a **google-cloud** asset, while the **postgres** instance is tagged as an **aws** asset.
  Both assets will be used in a **multi-cloud** ML pipeline.

For **training**: Click on the **dev** Greenplum database in the search results.
This will provide our **training environment**.
For this exercise, we will take the same training code that we used for the in-memory learner
and deploy it to the **VMware Greenplum** training instance we found in the **Data Catalog** earlier.
We will use Greenplum's **PL/Python** feature, which allows us to deploy Python code as a database **UDF** function.

Notice that the **training** instance is tagged with the label **aws**, indicating the platform where it is located.

<font color="red">NOTE</font>: How do we access the training instance?
Notice the tags that start with **servicebinding:** that have been associated with the **dev** instance.
Their specific names are **servicebinding:type:greenplum** and **servicebinding:provider:vmware**.
Thanks to **ServiceBindings**, these are the only keys we will need to connect to our Greenplum instance.

Navigate to the **TAP GUI** and click on the **pgadmin** instance:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/supply-chain
```

Launch pgAdmin by retrieving the URL from the **tanzu cli** (login credentials: test@test.com/alwaysbekind):
```execute
tanzu apps workload get pgadmin-tap --namespace pgadmin
```

Let's view the credentials for the **training** instance using the ServiceBindings **servicebinding:type:greenplum** and **servicebinding:provider:vmware**:
```execute
export PGADMIN_TMP_POD=$(kubectl get pod -l "app.kubernetes.io/part-of=pgadmin-tap,app.kubernetes.io/component=run" -oname -n pgadmin);
export PGADMIN_POD=$(echo ${PGADMIN_TMP_POD} | cut -b 5-);
kubectl cp ~/other/resources/pgadmin/show_server_import_file.sh pgadmin/$PGADMIN_POD:/tmp;
kubectl exec -it $PGADMIN_POD -n pgadmin -- sh -c "SRV_GRP_SUFFIX={{session_namespace}} /tmp/show_server_import_file.sh;"$(SRV_GRP_SUFFIX={{session_namespace}});
```

Observe that we were able to fetch the necessary DB credentials by using a ServiceBindings compatible library
(**pyservicebindings**).

Now return to pgAdmin and locate the Server connection instances which should be displayed as **Server Group Training {{session_namespace}}** and **Server Group Inference {{session_namespace}}**:
```dashboard:open-url
url: {{ ingress_protocol }}://pgadmin-tap.pgadmin.{{ DATA_E2E_BASE_URL }}
```

Next, we will view the PL/Python SQL function that will be used to train the model.

Fetch the code:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}};
export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && rm -rf ~/sample-ml-app;
git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git -b gp-main-{{session_namespace}} ~/sample-ml-app;
```

Let's view the PL/Python code:
```editor:open-file
file: ~/other/resources/plpython/sql/deploy_db_training.sql
text: "--liquibase"
after: 2
```

Notice the Liquibase **changeset** annotation, which will be used by our data versioning tool 
to log this script as a database change that can be tracked, versioned and rolled back if necessary.


Let's view the manifest for our pipeline.
The order of execution is as follows:
* **deploy-training** steps deploy the training model code (**Greenplum** instance).
* **run-training** steps execute the tasks to build and train the ML model (**Greenplum** instance).
* **deploy-inference** steps deploy the ML model to the inference cluster (**Postgres** instance).

First, we view the training steps:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: upload-dataset"
after: 24
```

We can see that the workflow comprises of *4* steps -
**upload_dataset**, **train-model**, **evaluate-model** and **promote-model-to-staging** -
with a set of **parameters** for each step.

Next, we view the steps that will deploy the **training** function:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: deploy-training-code"
after: 37
```

The **deploy-training** steps are responsible for deploying the Python code and PL/Python SQL script
that will be used for **training**.

Next, we view the steps that will deploy the **inference** function:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: deploy-inference-db"
after: 21
```

Next, we will use the lightweight **AppCR** resource to deploy and manage our pipeline.

Let's view the manifest for our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_gp.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.)

Update the training parameters for this workflow (under **train_model** --> **parameters**, increase **epochs** from 10 to 15):
```editor:open-file
file: ~/sample-ml-app/MLproject
```

Push to Git:
```execute
cp ~/other/resources/appcr/pipeline_app_gp.yaml ~/sample-ml-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_gp.yaml ~/sample-ml-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline-greenplum.yaml ~/sample-ml-app/pipeline.yaml;
cd ~/sample-ml-app; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git add .; git commit -m 'New commit'; git push origin gp-main-{{session_namespace}}; cd -; kapp deploy -a image-procesor-pipeline-gp-{{session_namespace}} -f ~/sample-ml-app/pipeline_app.yaml --logs -y  -n{{session_namespace}}
```

Let's access the web UI (you may need to click on the topmost menu tab on the left to see the initial screen):
```dashboard:open-url
url: https://argo-workflows.{{ ingress_domain }}
```

<font color="red">NOTE:</font> If the Login page is displayed, copy the access token from here to the Login box:
```execute
clear; kubectl -n argo exec $(kubectl get pod -n argo -l 'app=argo-server' -o jsonpath='{.items[0].metadata.name}') -- argo auth token
```

The newly deployed Argo pipeline should now be displayed.

For **inference**: The pipeline will take the same inference code that we used for the in-memory learners
and deploy it to the **Postgres-on-Kubernetes** training instance we found in the **Data Catalog** earlier.
That way, the inference code will be colocated with the apps.
We will use **PL/Python** to deploy the code, which is supported in Postgres.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>Why Postgres?</b><br/>
    As an inference store, Postgres has many features that make it a robust solution for serving in-database analytics.
    Among them is PL/X, or the ability to run programming languages like Python within the database process.
    This means that Postgres can also be used as an edge compute hub for integrating with message queues, APIs etc. during the feature processing phase.
</div>
<div style="clear: left;"></div>

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    If you search for the <b>pginstance-inference</b> database instance in the data catalog, 
    you'll see that it's been tagged with the label "gcp".
    Since the training instance is on "aws", this means that we will be deploying a <b>multi-cloud</b> pipeline.
</div>
<div style="clear: left;"></div>

Here is the inference code:
```editor:open-file
file: ~/other/resources/plpython/sql/deploy_db_inference.sql
```

To invoke the inference code which is deployed to the Postgres database,
we will also use **GreenplumPython**, which allows us to interact with Greenplum and Postgres using Python code.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>What is GreenplumPython?</b><br/>
    GreenplumPython is a Python library that enables the user to interact with Greenplum in a Pythonic way.
    Learn more about GreenplumPython here: <a href="https://greenplum-db.github.io/GreenplumPython/stable/">Home Page</a>
</div>
<div style="clear: left;"></div>

Here is the app code that invokes the inference function using **GreenplumPython**:
```editor:select-matching-text
file: ~/sample-ml-app/app/analytics/cifar_cnn_greenplum.py
text: "name: deploy-inference-db"
after: 21
```

In both the training and inference, we are using **Liquibase** to update the target databases with the appropriate UDF functions.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>What is Liquibase?</b><br/>
    Liquibase is a popular library for managing and applying changes to structured databases in a versioned, trackable, DevOps-friendly manner.
    Learn more about Liquibase here: <a href="https://www.liquibase.com/">Home Page</a>
</div>
<div style="clear: left;"></div>

Return to **pgAdmin** and select _Databases -> pginstance-inference -> Schemas -> {{session_namespace}}_ to select the Postgres inference instance.
Then right-click the database schema, select "Query Tool", and run the following query:
```copy
SELECT * FROM "{{session_namespace}}".databasechangelog;
```

The database changes are successfully being tracked (managed by Liquibase).

#### Promote model
Navigate to MlFlow:
```dashboard:open-url
url: {{ ingress_protocol }}://mlflow.{{ ingress_domain }}
```

Select the **convolutional_neural_network_team_main** experiment (on the left),
and enter **metrics.accuracy_score > 0.5** in the search field, then select the run in the search results.

#### Launch API
To invoke the API from TAP, click on the link below, then click on the "Definition" tab:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/api-docs
```

The rendered view should be similar to this interface:
```dashboard:open-url
url: {{ ingress_protocol }}://image-processor-api.default.{{ DATA_E2E_BASE_URL }}/docs
```

Try uploading the images from earlier to test out the API.


#### Launch app from TAP GUI
Relaunch the app by clicking on the URL from the **tanzu** cli:
```execute
tanzu apps workload get image-processor --namespace default
```

Upload an image and observe the app's prediction results, as well as the performance metrics.
In some cases, the results may be inaccurate.
The pipeline can be extended to monitor the performance of the app in production,
and trigger re-training based on a pre-configured alert threshold.
In this case, the ML metrics can be used to configure the "retrain" threshold.