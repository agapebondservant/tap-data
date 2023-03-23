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

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/mlops-tip.png"> 
    The data catalog was deployed to TAP using a Workload template provided by an <b>Accelerator</b>.
    For more info, search for <b>datahub</b> on the TAP Accelerators page.
</div>
<div style="clear: left;"></div>


From **TAP GUI**, go to the **Worklooads** screen:
```dashboard:open-url
url: http://tap-gui.tanzumlai.com/supply-chain
```

Click on the DataHub workload (it should show up as **datahub-tap**.) Notice that the app is in *Ready** state.

Launch DataHub by clicking on the URL from the **tanzu** cli:
```execute
tanzu apps workload get datahub-tap --namespace default
```

Login to **DataHub** (credentials: **datahub/datahub**). 

Next, enter **"data lake"** in the Search Bar (include the double quotes), and select the Tag in the dropdown that displays.
The results should show that the **"data lake"** tag was applied to 1 Dataset; click on that link.

Click on the asset that displays in the results (it should be a parquet file). 
It has been previously tagged in DataHub as a **Data Lake** asset. This data source contains the data that will be used for our experiments.
Click on the "Properties" tab to view more detail.

Next, we will work on discovering the tooling that we will need for our development environment.
