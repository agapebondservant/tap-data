### Building ML Model with VMware Greenplum

In the previous exercise, we demonstrated how to build an **in-memory learner**. 
This means that there was no need to scale our training cluster, because the available RAM was large enough to fit the model.
We also built a single-cluster learner, as **training** and **serving** were performed on the same cluster.

However, sometimes we may find that our ML models, data and/or features are too large or complex to fit into the available resources on a single node.
We might use **machine learning curves** or similar to discover that we need to scale out our system so that we can 
train and/or serve in a more **distributed** environment. This would result in an **out-of-core learner**.

There are many different approaches for this. 
One popular approach is to use separate clusters for **training** and **inference**.
**Training** is done on a highly parallelized cluster that is colocated where the **data** resides, while 
**inference** occurs on a separate cluster that is colocated where the **apps/consumers** reside.

In this session, we will use **in-database analytics** to move the training compute where the **data** resides.
This way, our training pipelines will actually run within the database itself.
**Tanzu Application Platform** can easily integrate with just about any database using **Service Bindings**, which we will explore momentarily.

In this exercise, we will use **VMware Greenplum** for in-database analytics.

For **training**: We will take the same training code that we used for the in-memory learners 
and deploy it to the **VMware Greenplum** training instance we found in the **Data Catalog** earlier.
We will use Greenplum's **PL/Python** feature, which allows us to deploy Python code as a database **UDF** function.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>What is VMware Greenplum?</b><br/>
    VMware Greenplum is a massively parallel processing data platform for large-scale analytics and data processing.
    Learn more about VMware Greenplum here: <a href="https://docs.vmware.com/en/VMware-Tanzu-Greenplum/index.html" target="_blank">Home Page</a>
</div>
<div style="clear: left;"></div>

For **inference**: We will take the same inference code that we used for the in-memory learners
and deploy it to the **Postgres-on-Kubernetes** training instance we found in the **Data Catalog** earlier.
We will use **PL/Python** here, which is available in both Greenplum and Postgres.
We will also use **GreenplumPython**, which allows us to interact with Greenplum using Python code.
In both cases, we will use **Liquibase** to update the target databases with the appropriate UDF functions.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    <b>What is Liquibase?</b><br/>
    Liquibase is a popular library for managing and applying changes to structured databases in a versioned, trackable, DevOps-friendly manner.
    Learn more about Liquibase here: <a href="https://www.liquibase.com/">Home Page</a>
</div>
<div style="clear: left;"></div>


Let's access the web UI (you may need to click on the topmost menu tab on the left to see the initial screen):
```dashboard:open-url
url: https://argo-workflows.{{ ingress_domain }}
```

<font color="red">NOTE:</font> If the Login page is displayed, copy the access token from here to the Login box:
```execute
clear; kubectl -n argo exec $(kubectl get pod -n argo -l 'app=argo-server' -o jsonpath='{.items[0].metadata.name}') -- argo auth token
```

Let's view the manifest for our Argo Workflow:
```editor:select-matching-text
file: ~/other/resources/argo-workflows/pipeline-greenplum.yaml
text: "servers"
after: 16
```

We can still see that the workflow comprises of *4* steps -
**upload_dataset**, **train-model**, **evaluate-model** and **promote-model-to-staging** -
with a set of **parameters** for each step. 

In addition, we see that there are a few new steps. 
The **deploy-training** steps are responsible for deploying the Python code and PL/Python SQL script
that will be used for **training**, while the **deploy-inference** steps handle the same thing for **inference**.
Hence, the order of execution is as follows:
* **deploy-training** steps deploy the training model code (Greenplum instance).
* **run-training** steps execute the tasks to build and train the ML model (Greenplum instance).
* **deploy-inference** steps deploy the ML model to the inference cluster (Postgres instance).










