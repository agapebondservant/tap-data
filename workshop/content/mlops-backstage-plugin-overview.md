### Exploring the Backstage ML Portal in Tanzu Developer Portal

#### Launch Jupyter notebook from ML Portal
TAP's **Tanzu Developer Portal** is a customizable portal that can be extended to incorporate different **Backstage plugins**.
**Backstage** is an opensource framework that teams can use to configure a unified portal for all of their resources - 
infrastructure, services and documentation.

(<font color="red">NOTE:</font> For more information on **Backstage**, see the <a href="https://backstage.io/docs/overview/what-is-backstage" target="_blank">official docs<a/>.)

An example of a Backstage plugin extension is the **Backstage ML Portal**.
With this portal, data scientists can discover different Data / ML tools, pipelines and platforms that have been previously made available to them 
by a **Platform Operator**.
They can also use it to connect their Jupyter notebooks (and other similar IDEs) to the datasources or endpoints of their choosing.

Navigate to the **ML Panel**:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.tanzudatatap.com/mlworkflows
```

You can see tabs for different categories of services: **Data**, **Models**, **Pipelines**, **Clusters** and **Experiments**.

Thanks to **Backstage Components**, the actual items on each tab are configurable.
Where appropriate, users can add, remove or update tiles by simply navigating to the **Catalog** page:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.tanzudatatap.com/catalog
```

From there, they can make changes to the underlying YAML config by clicking on the **mltools-metadata** component -> "View Source".
The underlying metadata file from GitHub is displayed, and may be edited as appropriate by authorized users.

<font color="red"><b>NOTE: A separate workshop will go into the plugin configuration in more detail.</b></font>

Back on the **ML Panel**, click on the **Data** tab, and click **CONSOLE** on the Greenplum tile. 
The **Greenplum Command Center** is displayed.
Generally, the **CONSOLE** button links to any existing management console UI - or any other relevant GUI - that has been set up for access by the user.
If no console has been set up, then the **CONSOLE** will not be displayed.

Next, click on **CONNECT** tab, and click on the _copy_ icon for the displayed **ServiceBinding**.
**ServiceBindings** are a Kubernetes spec that can be used to connect to services without having to tamper with sensitive credentials.

For this demo, we will use our copied clipboard to connect to this Greenplum instance.
Click on the **Experiments** tab, and click on **CONSOLE** on the Jupyter tile.

Login to the JupyterLab environment (credentials: **jhub/Vmware1!**).
There should be a templated notebook available - **connect-template.ipynb**.
Click on the notebook to launch it.
Then:
* Launch a new cell (hover underneath the existing cell for the "Click to add a cell" link to appear);
* Copy all the lines underneath `# For Greenplum` to the new cell;
* Replace **bkstg-xxx-name-of-service-binding** with the value of the **ServiceBinding** just copied;
* Uncomment the content (using **Cmd + /** on Mac or **Ctrl + /** on Windows); and 
* Run the cell (using **Cmd + Enter** on Mac or **Ctrl + Enter** on Windows). 

Data from the Greenplum query should be displayed in a <a href="https://pandas.pydata.org/" target="_blank">pandas</a> **DataFrame**.