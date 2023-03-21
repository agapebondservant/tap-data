### Using a Data Catalog for Data Asset Discovery

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
(DataHub has already been pre-installed for this workshop; we will go over self-service provisioning of ML tools in a separate section.)

From **TAP GUI**, go to the **Worklooads** screen:
```dashboard:open-url
url: http://tap-gui.tanzumlai.com/supply-chain
```

Click on the DataHub workload (it should show up as **datahub-tap**.) Notice that the app is in *Ready** state.

Launch DataHub by clicking on the URL from the **tanzu** cli:
```execute
tanzu apps workload get datahub-tap --namespace default
```

View **DataHub** here (login: **datahub/datahub**), and search for "Greenplum CIFAR Data Source":
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

Login to **DataHub** (credentials: **datahub/datahub**), and click on the DataHub icon (top-left).

Next, in the **View** search bar towards the top (with the prompt text "Create a View"), 
enter **ServiceBinding Sources** in the Search Bar (include the double quotes).
These are the assets that have been previously tagged as **ServiceBinding** resources.
**ServiceBindings** is a Kubernetes-standard specification for connecting apps with databases, API services and 
other resources, and it is supported out of the box by **TAP**. More on **ServiceBindings** will be explored later in the session.

The results should include 1 **greenplum** database and 1 **postgres** database. Click on each link and explore each asset. 

Notice the following:
*The **greenplum** database has been tagged as a **training** asset. This is the dataset that will be used for **training**.
*The **postgres** database has been tagged as an **inference** asset. This is the dataset that will be used for **inference**.
*The Greenplum instance is tagged as a **google-cloud** asset, while the **postgres** instance is tagged as an **aws** asset.
Both assets will be used in a **multi-cloud** ML pipeline. 

Next, we will work on discovering the tooling that we will need for our development environment.
