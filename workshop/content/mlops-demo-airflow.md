### Deploying Apache Airflow

#### Introduction

![Apache Airflow](images/airflow.png)

**Apache Airflow** is a popular workflow management system for scheduling and orchestrating data pipelines.

We will use **TAP** to deploy a scalable, resilient instance of **Apache Airflow** on our cluster. 

For this deployment, we will leverage the **KubernetesExecutor** for resilience and isolation.
(Click <a href="https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/kubernetes.html" target="_blank">here</a> to learn more about the **KubernetesExecutor**.)

Also, we will use **Git-Sync** to allow our **DAG files** in GitHub to be synced automatically with our cluster.
(Click <a href="https://airflow.apache.org/docs/helm-chart/stable/manage-dags-files.html" target="_blank">here</a> to learn more about the **Git-Sync** feature.)

Here is the **DAG** that will be synced:
```dashboard:open-url
url: {{DATA_E2E_AIRFLOW_DAGS_REPO}}
```

<font color="red"><b>NOTE:</b></font> This will be a one-off deployment. Normally, we will use **GitOps pipelines** to deploy and manage our **Apache Airflow** instances.

Let's begin!

#### Launch Kubeapps
**Kubeapps** provides a self-service, web-based GUI for deploying and managing applications to Kubernetes.

Launch **Kubeapps** using the URL provided here:
```execute
export KUBEAPPS_SERVICE_IP=$(kubectl get svc --namespace {{session_namespace}} kubeapps -o jsonpath="{.status.loadBalancer.ingress[0]['hostname', 'ip']}");
echo "http://${KUBEAPPS_SERVICE_IP}"
```

Use the token generated below to login:
```execute
kubectl delete serviceaccount kubeappuser -n {{session_namespace}} || true; 
kubectl create -n {{session_namespace}} serviceaccount kubeappuser;
kubectl delete clusterrolebinding kubeappuser{{session_namespace}}binding || true; 
kubectl create clusterrolebinding kubeappuser{{session_namespace}}binding --clusterrole=cluster-admin --serviceaccount={{session_namespace}}:kubeappuser;
export KUBEAPPS_SERVICE_IP_TOKEN=$(kubectl create token kubeappuser -n {{session_namespace}});
echo $KUBEAPPS_SERVICE_IP_TOKEN
```

In the top right, select the dropdown under **Current Context**, copy the text below to the **Namespace** dropdown, and click "Change Context":
```copy
{{session_namespace}}
```

Next, go to the **Catalog** tab, click on "Airflow", and click "Deploy". 

The Visual Editor screen should show up with the content of the **values.yaml** file.
Updating the content will allow us to override the configuration for our deployment.

For a baseline, we can search for a predefined template with TAP's **Accelerators**.
Launch the Accelerator view:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/create
```

On the **Airflow Accelerator**, click **Choose**. A list of configurable entries should be displayed, as well as
a link to the official documentation for the Airflow package. For this exercise, we'll keep the default values as is. 

Click on **Explore**. Under the **bitnami-airflow** folder, notice that there are multiple subfolders for each configured app version of Airflow.
The version that we will use for this exercise is **2.8.1**.
Navigate to **bitnami-airflow/2.8.1/values.yaml** in the displayed window, and click **Copy**. 

Now, return to **KubeApps** and replace the content of the textarea with the values you just copied.

**KubeApps** includes a list of **chart versions** that can be deployed.
Click on the **Package Version** dropdown on the top right, and select **16.6.0 / App Version 2.8.1**.
This version matches the app version that we configured earlier.
Then click "Deploy".

In the YAML editor, our updates to the default configuration should be visually displayed in _diff_ format.
This allows us to validate our updates;
it also allows us to spot any breaking changes to the YAML config that we may need to backfill before deploying.
Then, click the "Deploy" button below.


<font color="red"><b>NOTE:</b></font> This may take up to a few minutes to deploy. Once fully deployed, **KubeApps** should display an indicator 
showing that the deployment is complete. Refresh your screen after a minute if the status doesn't show the update right away.

Meanwhile, you can monitor the new **Apache Airflow** cluster nodes by clicking on the console below and scrolling to the **airflow** pods.

Once **Apache Airflow** is deployed, click on the **LoadBalancer IP** shown and log in using the configured credentials (admin/admin).
The **DAG** from our GitHub repository should be shown in **Paused** state. Click on **Play** to activate the **DAG**.

You can monitor the new worker nodes by clicking on the console below and typing **/tanzu-kubernetes**.
<font color="red"><b>NOTE:</b></font> Click **Esc** to exit this mode before proceeding.