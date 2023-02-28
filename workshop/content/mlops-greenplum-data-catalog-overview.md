### Using a Data Catalog for Metadata Management

Effective ML starts with the **quality of data**. This concept is known as the "Unreasonable Effectiveness of Data". 
Time and time again, it has been discovered that data quality - in terms of size, variability, staleness etc - is much more important to 
the performance of the model than the actual model itself. 

Hence, we need a way to discover and curate quality **data sets** for our models. 
Quality data starts with quality metadata; hence, we will need a **metadata management** platform to enable data quality.

We will use a **Data Catalog** for this. In this exercise, we will be using **DataHub** as our data catalog.

View **DataHub** here (login: **datahub/datahub**), and search for "Greenplum CIFAR Data Source":
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

To view the **Assets** associated with our datasource, click on "Details" under the data source, 
then click "View All" in the *Ingested Assets* section.

<font color="red"><b>TODO:</b> Train model in Greenplum and migrate to Postgres sink via Liquibase.</font>
