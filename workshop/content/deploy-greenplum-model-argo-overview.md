### Building ML Model using In-Database Analytics

In the previous exercise, we demonstrated how to build an **in-memory learner**.
This means that there was no need to scale our training cluster, because the available compute and memory resources was large enough to fit the model.
We also built a single-cluster learner, as **training** and **serving** were performed on the same cluster.

However, sometimes we may find that our ML models, data and/or features are too large or complex to fit into the available resources on a single node.
We might use **machine learning curves** or similar to discover that we need to scale out our system so that we can
train and/or serve in a more **distributed** environment. This would result in an **out-of-core learner**.

#### In-Database Analytics
There are many different approaches for scaling an ML environment.
One popular approach is to use separate clusters for **training** and **inference**.
**Training** is done on a highly parallelized cluster that is colocated where the **data** resides, while
**inference** occurs on a separate cluster that is colocated where the **apps/consumers** reside.

In this session, we will use **in-database analytics** to move the training compute where the **data** resides.
This way, our training pipelines will actually run within the database itself.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    Also, in-database analytics often includes native support for queries that can be challenging to achieve in a distributed environment,
    such as distributed joins, sorts, aggregations and parallelization.
</div>
<div style="clear: left;"></div>

![Data movement](images/data-movement.jpg)

**Tanzu Application Platform** can easily integrate with just about any modern database using **Service Bindings**, which we will explore momentarily.
This includes databases with support for **in-database analytics**.
In this exercise, we will use **VMware Greenplum** for in-database analytics.

Let's go back to our datasets from the data catalog:
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

Login (credentials: **datahub/datahub**), go to the Home Page (click on the top-left icon), 
click on the "Explore all" link and select **ServiceBinding Sources**
in the **View** search bar towards the top (with the prompt text "Create a View").

For **training**: Click on the **dev** Greenplum database in the search results.
This will provide our **training environment**.
For this exercise, we will take the same training code that we used for the in-memory learner
and deploy it to the **VMware Greenplum** training instance we found in the **Data Catalog** earlier.
We will use Greenplum's **PL/Python** feature, which allows us to deploy Python code as a database **UDF** function.

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

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    pgAdmin was deployed to TAP using a Workload template provided by an <b>Accelerator</b>.
    For more info, search for <b>pgadmin</b> on the TAP Accelerators page.
</div>
<div style="clear: left;"></div>

Let's add a new Server connection for the Greenplum instance by creating a server import file:
```execute
export PGADMIN_TMP_POD=$(kubectl get pod -l "app.kubernetes.io/part-of=pgadmin-tap,app.kubernetes.io/component=run" -oname -n pgadmin);
export PGADMIN_POD=$(echo ${PGADMIN_TMP_POD} | cut -b 5-);
kubectl cp ~/other/resources/pgadmin/show_server_import_file.sh pgadmin/$PGADMIN_POD:/tmp;
kubectl exec -it $PGADMIN_POD -n pgadmin -- sh -c "SRV_GRP_SUFFIX=tanzu-mlops-w03-s001 /tmp/show_server_import_file.sh;"
```

Observe that we were able to fetch the necessary DB credentials by using a ServiceBindings compatible library
(**pyservicebindings**).

Now we will import the server file:
```execute
export PGADMIN_TMP_POD=$(kubectl get pod -l "app.kubernetes.io/part-of=pgadmin-tap,app.kubernetes.io/component=run" -oname -n pgadmin);
export PGADMIN_POD=$(echo ${PGADMIN_TMP_POD} | cut -b 5-);
kubectl cp ~/other/resources/pgadmin/import_server_import_file.sh pgadmin/$PGADMIN_POD:/tmp;
kubectl exec -it $PGADMIN_POD -n pgadmin -- sh -c "SRV_GRP_SUFFIX=tanzu-mlops-w03-s001 /tmp/import_server_import_file.sh;"
```

Now refresh pgAdmin - the new Server connection instances should be displayed:
```dashboard:open-url
url: {{ ingress_protocol }}://pgadmin-tap.pgadmin.{{ DATA_E2E_BASE_URL }}
```

Next, let's fetch the code:
```execute
clear; export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}} && export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && rm -rf ~/sample-ml-app && git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git -b gp-main-{{session_namespace}} ~/sample-ml-app
```

Since we are using **in-database analytics**, we need to deploy this code to the Greenplum database.
In the left hand panel, select _Databases -> dev -> schema -> {{session_namespace}} -> Functions_. This should be empty at first.
Our pipeline will take care of deploying the code that will be used to train the model.
In this case, it will involve a new DB change.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    <b>Why should we use a pipeline orchestrator?</b><br/>
    By decoupling the pipeline from its orchestration, it is easier to perform management tasks like retries and rollbacks.
    Orchestration also helps with standardizing pipeline deployment for reuse/repeatability, 
    and decoupling pipeline steps for greater flexibility and integration: for example, it provides the ability 
    to leverage multiple languages and frameworks in the same pipeline.
    Pipeline orchestration is necessary to achieve <b>Level 1</b> MLOps maturity.
</div>

Let's search on the **Accelerators** page for a prebuilt template that we can use - enter "in-database" in the Search field:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    You can explore the In-Database Analytics accelerator for a more in-depth overview.
</div>
<div style="clear: left;"></div>

Let's view the manifest for our pipeline:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: upload-dataset"
after: 24
```

We can still see that the workflow comprises of *4* steps -
**upload_dataset**, **train-model**, **evaluate-model** and **promote-model-to-staging** -
with a set of **parameters** for each step.

In addition, we see that there are a few new steps:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: deploy-training-code"
after: 37
```

The **deploy-training** steps are responsible for deploying the Python code and PL/Python SQL script
that will be used for **training**.

The **deploy-inference** steps handle the same thing for **inference**:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "name: deploy-inference-db"
after: 21
```

Hence, the order of execution is as follows:
* **deploy-training** steps deploy the training model code (**Greenplum** instance).
* **run-training** steps execute the tasks to build and train the ML model (**Greenplum** instance).
* **deploy-inference** steps deploy the ML model to the inference cluster (**Postgres** instance).

Like before, we will use the lightweight **AppCR** resource to deploy and manage our pipeline.

(<font color="red">NOTE:</font> Learn more about App CR here: <a href="https://carvel.dev/kapp-controller/docs/v0.38.0/app-overview/" target="_blank">Argo Workflows</a>)

Let's view the manifest for our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_gp.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.)

Let's copy the App CR and pipeline files to our ML code directory:
```execute
cp ~/other/resources/appcr/pipeline_app_gp.yaml ~/sample-ml-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_main.yaml ~/sample-ml-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline.yaml ~/sample-ml-app/pipeline.yaml
```

Our directory now looks like this:
```execute
ls -ltr ~/sample-ml-app
```

To kick off pipeline orchestration for our ML pipeline, let's commit the App CR to Git and deploy the App CR:
```execute
cd ~/sample-ml-app; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git add .; git commit  -m 'New commit'; git push origin gp-main-{{session_namespace}}; cd -; kapp deploy -a image-procesor-pipeline-gp-{{session_namespace}} -f ~/sample-ml-app/pipeline_app.yaml --logs -y  -n{{session_namespace}}
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

At the end, the ML model will be available in the Model Registry:
```dashboard:open-url
url: https://mlflow.{{ ingress_domain }}/#/models
```

For **inference**: The pipeline will take the same inference code that we used for the in-memory learners
and deploy it to the **Postgres-on-Kubernetes** training instance we found in the **Data Catalog** earlier.
That way, the inference code will be colocated with the apps.

To invoke the inference code which is deployed to the Postgres database,
we will also use **GreenplumPython**, which allows us to interact with Greenplum and Postgres using Python code.

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

#### APIs
To invoke the API from TAP, we'll go the TAP API Portal.
Click on the link below, then click on the "Definition" tab:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/api-docs
```

The rendered view should be similar to this interface:
```dashboard:open-url
url: {{ ingress_protocol }}://image-processor-api.{{ DATA_E2E_BASE_URL }}/docs
```

Try uploading the images from earlier to test out the API.