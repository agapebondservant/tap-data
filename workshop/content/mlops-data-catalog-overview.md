### Using a Data Catalog for Data Asset Discovery

In order to begin, we will need to discover a suitable **data source** that can provide CIFAR-10 data for our object detection experiments.
This is a part of the **Discovery** phase.

We will use a **Data Catalog** for this. A **Data Catalog** is a data discovery tool that uses metadata management to ensure data quality.

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/tip.png"> 
    <b>Why is a data catalog necessary?</b><br/>
    Effective ML starts with the <b>quality of data</b>. This concept is known as the "Unreasonable Effectiveness of Data". 
    Time and time again, it has been shown that data quality - based on size, variability, staleness etc - is much more important to 
    the performance of the model than the actual model itself. 
    Hence, we need a way to discover and curate quality <b>data sets</b> for our models. 
    Quality data requires quality metadata, so we will need a <b>metadata management</b> platform to enforce data quality.
</div>
<div style="clear: left;"></div>

In this exercise, we will be using **DataHub** as our data catalog.

View **DataHub** here (login: **datahub/datahub**), and search for "Greenplum CIFAR Data Source":
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

To view the **Assets** associated with our datasource, click on "Details" under the data source, 
then click "View All" in the *Ingested Assets* section.

<font color="red"><b>TODO:</b> Train model in Greenplum and migrate to Postgres sink via Liquibase.</font>
