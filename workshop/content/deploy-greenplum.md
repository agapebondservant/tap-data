
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

```execute
sed -i 's/YOUR_GREENPLUM_CLUSTER/gpdb-cluster-{{session_namespace}}/g' ~/other/resources/greenplum/greenplum-cluster.yaml && kubectl delete greenplumcluster gpdb-cluster-{{session_namespace}} --ignore-not-found=true -n greenplum-system && kubectl apply -f ~/other/resources/greenplum/greenplum-cluster.yaml -n greenplum-system
```

Now, we will test out PXF by performing a federated query. Open a bash shell:
```execute
kubectl exec -it master-0 -n greenplum-system -- bash -c "source ./.bashrc; madpack -p greenplum install" && kubectl exec -it master-0 -n greenplum-system -- bash
```

Notice we also installed the functions for **MADLib**.

Connect to the **psql** subsytem:
```execute
psql -d gpadmin
```

Create the PXF extension, then create an external table for the CSV file loaded earlier and query the external table:
```execute
CREATE EXTENSION IF NOT EXISTS pxf;
CREATE EXTERNAL TABLE madlib.pxf_clinical_data_000(clinic_id int,clinic_name varchar(300),state varchar(2),clinic_full_name varchar(300),region varchar(50),dog_breed  varchar(50),cat_breed varchar(50),fish_breed varchar(50),bird_breed varchar(50),treatment_cost int,wait_time int,recommended boolean)  LOCATION ('pxf://pxf-data/data-samples-w01-s001/1-clinical-reviews.csv?PROFILE=s3:text&FILE_HEADER=USE&S3_SELECT=AUTO') FORMAT 'TEXT' (delimiter=E',');
SELECT * FROM madlib.pxf_clinical_data_000;
```