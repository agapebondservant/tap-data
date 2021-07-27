
### Deploying Tanzu Greenplum

**Tanzu Greenplum** is a petabyte-scale, MPP,  distributed data warehouse with **HTAP** _(Hybrid Transactional Analytical Processing)_ capabilities.

Let's configure **PXF** (Platform Extension Framework) for our cluster. We will do this by setting up an **S3-compatible bucket path** for our PXF configuration, which will provide the datastore-specific metadata that the PXF service needs in order to interact with external datasources. This configuration will be used to launch a separate set of dedicated nodes (pods) that will act as the agents for receiving query requests from segment instances, and delegating the requests to the appropriate external data source. We will also set up a second **S3-compatible**  bucket as our external data store. 

```execute
clear  && mc config host add data-e2e-minio {{DATA_E2E_MINIO_URL}} {{DATA_E2E_MINIO_ACCESS_KEY}} {{DATA_E2E_MINIO_SECRET_KEY}} && kubectl create secret generic data-e2e-greenplum-pxf-configs --from-literal='access_key_id={{DATA_E2E_MINIO_ACCESS_KEY}}' --from-literal='secret_access_key={{DATA_E2E_MINIO_SECRET_KEY}}' --namespace=greenplum-system --dry-run -o yaml | kubectl apply -f - && mc mb -p data-e2e-minio/pxf-config && mc mb -p data-e2e-minio/pxf-data/{{ session_namespace }} && mc cp ~/other/resources/greenplum/minio-site.xml data-e2e-minio/pxf-config/servers/default/minio-site.xml && mc cp ~/other/resources/data/*.csv data-e2e-minio/pxf-data/{{ session_namespace }}
```

Next, let's proceed to deploy our **PXF-enabled** Greenplum cluster. Let's take a look at the S3-compatible buckets that are available to us:

```execute
mc ls data-e2e-minio
```

Next, let's take a look at the manifest that we will use to deploy our **GreenplumPXFService**:

```editor:open-file
file: ~/other/resources/greenplum/greenplum-pxf.yaml
```

Let's go ahead and deploy our **PXF** service.

```execute
kubectl apply -f ~/other/resources/greenplum/greenplum-pxf.yaml -n greenplum-system
```

Next, let's take a look at the manifest that we will use to deploy our **GreenplumCluster**:
```editor:select-matching-text
file: ~/other/resources/greenplum/greenplum-cluster.yaml
text: YOUR_GREENPLUM_CLUSTER
```

Now, let's go ahead and deploy our new cluster.
<font color="red">Do NOT run this unless this is the first workshop instance, i.e. the workspace ends with **s001**.</font>
```execute
sed -i 's/YOUR_GREENPLUM_CLUSTER/gpdb-cluster-{{session_namespace}}/g' ~/other/resources/greenplum/greenplum-cluster.yaml && kubectl delete greenplumcluster gpdb-cluster-{{session_namespace}} --ignore-not-found=true -n greenplum-system && kubectl apply -f ~/other/resources/greenplum/greenplum-cluster.yaml -n greenplum-system
```

Now, we will test out PXF by performing a federated query. Open a bash shell:
```execute
kubectl wait --for=condition=Ready pod/master-0 -n greenplum-system --timeout=300s && kubectl get svc greenplum -n greenplum-system -o json | jq '.spec.ports[0].name="gpdb" | .spec.ports[.spec.ports | length] |= . + {name:"gpcc",port:28080,protocol:"TCP",targetPort:28080} | {"spec":{"ports":.spec.ports}} ' > /tmp/gpcc.txt && kubectl patch svc greenplum -n greenplum-system --patch "$(cat /tmp/gpcc.txt)" && kubectl exec -it master-0 -n greenplum-system -- bash
```

Wait for the greenplum database to start up:
```execute
source ./.bashrc; gpstate  -s;
```

## MADLib
Install the functions for **MADLib**. <font color="red">NOTE: The following also installs the Greenplum Command Center; when shown the **End User License Agreement**, repeatly type **Ctrl-F** and enter "y" when prompted:</font>
```execute
echo -e "path = /greenplum\ndisplay_name = gpcc\nweb_port = 28080\nenable_ssl = false" > /tmp/gpcc-config.txt && PGPASSWORD=changeme /tools/installGPCC/gpccinstall-* -c /tmp/gpcc-config.txt &&  source /greenplum/greenplum-cc/gpcc_path.sh && PGPASSWORD=changeme gpcc start && madpack -p greenplum install
```

View all the events in the Greenplum Command Center (login with creds *pgmon/changeme*):
```dashboard:create-dashboard
name: Greenplum
url: {{ ingress_protocol }}://{{ session_namespace }}-greenplum.{{ ingress_domain }}
```

Connect to the **psql** subsytem:
```execute
psql -d gpadmin
```

Create the PXF extension, then create an external table for the CSV file loaded earlier and query the external table:
```execute
CREATE EXTENSION IF NOT EXISTS pxf;
DROP EXTERNAL TABLE IF EXISTS madlib.pxf_clinical_data_000 CASCADE;
DROP TABLE IF EXISTS madlib.clinical_data_logreg, madlib.clinical_data_logreg_summary;
CREATE EXTERNAL TABLE madlib.pxf_clinical_data_000(review_id varchar(7), clinic_id varchar(10),clinic_name varchar(300),state varchar(2),region varchar(50),dog_breed  varchar(50),cat_breed varchar(50),fish_breed varchar(50),bird_breed varchar(50),treatment_cost int,wait_time int,recommended boolean)  LOCATION ('pxf://pxf-data/{{session_namespace}}/clinical-reviews-batch-001.csv?PROFILE=s3:text&FILE_HEADER=USE&S3_SELECT=AUTO') FORMAT 'TEXT' (delimiter=E',');
CREATE VIEW madlib.pxf_clinical_data_000_vw AS SELECT * FROM madlib.pxf_clinical_data_000;
```

Let's view the source data: 
```execute
SELECT * FROM madlib.pxf_clinical_data_000;
```
Enter **Ctrl-C** to exit.

<font color="red">In **Jupyter**, run the *Connect to Greenplum and view clinical recommendation data* cell. As Jupyter Notebook is being launched for the first time, login to the Jupyter app (password "jupyter"), launch the Jupyter Terminal app and run the command below: (will be copied to the clipboard)</font>:
```copy
pip install -r jupyter/requirements.txt
```

Next, let's generate train and test subsets of the data using an 80/20 train-test split;
```execute
DROP TABLE IF EXISTS madlib.pxf_clinical_data_000_out_train, madlib.pxf_clinical_data_000_out_test;
SELECT madlib.train_test_split('madlib.pxf_clinical_data_000_vw','madlib.pxf_clinical_data_000_out',
                                0.8, NULL, NULL, NULL, FALSE, TRUE);

```

Next, let's generate the model from the train set and use it to generate predictions from the test set:
```execute
SELECT madlib.logregr_train('madlib.pxf_clinical_data_000_out_train',
'madlib.clinical_data_logreg',
'recommended','ARRAY[1, treatment_cost, wait_time]');

DROP TABLE IF EXISTS madlib.clinical_data_test_results;
CREATE TABLE madlib.clinical_data_test_results(pred FLOAT8, obs BOOLEAN);
INSERT INTO madlib.clinical_data_test_results(
    SELECT madlib.logregr_predict_prob(coef, ARRAY[1, treatment_cost, wait_time]),source.recommended
    FROM madlib.pxf_clinical_data_000_out_test source, madlib.clinical_data_logreg m);
```

Now we will be able to generate Binary Classifier metrics, which we will use to generate the **True Positive Rate** (tpr), **False Positive Rate** (fpr) and the AUROC curve:
```execute
DROP TABLE IF EXISTS madlib.clinical_data_test_result_metrics,  madlib.clinical_data_test_result_roc;
SELECT madlib.binary_classifier( 'madlib.clinical_data_test_results', 'madlib.clinical_data_test_result_metrics', 'pred', 'obs');
SELECT madlib.area_under_roc( 'madlib.clinical_data_test_results', 'madlib.clinical_data_test_result_roc', 'pred', 'obs');
```

Now that we have our logistic model, we have come to the **Predict**  stage of the machine learning workflow (**Remember - Formulate - Predict**). Let's go ahead and operationalize our model by publishing it via an interoperable interface, like a REST API. There are many approaches for this. With Tanzu Data, we have a low-code option available to use: we can use **Spring Cloud Data Flow** to set up a streaming job which will update Gemfire, an in-memory database which includes built-in support for exposing data objects via a REST management interface. Let's work on that next.

```execute
\q
```

Exit the psql shell:
```execute
exit
```