
### Overview

Now, let's create a file ingest pipeline with **VMware Spring Cloud Data Flow**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:reload-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ DATA_E2E_BASE_URL }}/dashboard
```

<font color="red">In **Jupyter**, open the *File Ingestion Notebook* and run the *Connect to Postgres and view test database table* cell. As Jupyter Notebook is being launched for the first time, login to the Jupyter app (password "jupyter"), launch the Jupyter Terminal app and run the command below: (will be copied to the clipboard)</font>:
```copy
pip install -r jupyter/requirements.txt
```

Under the cell *Set variables*, provide the value of TESTDBPASSWORD by copying the results of the following block, then execute the Jupyter cell:
```execute
kubectl get secret pginstance-1-db-secret -o jsonpath="{.data.password}" | base64 --decode
```

Back on the Spring Cloud Data Flow dashboard, create the following pipeline:
```copy
jdbc --spring.datasource.url="jdbc:postgresql://postgres.{{ session_namespace }}.svc.cluster.local:5432/postgres" --spring.datasource.username="postgres" --spring.datasource.password="changeme" --jdbc.supplier.query="select row_to_json(logreg) from (select coef, log_likelihood, std_err,z_stats,p_values,odds_ratios,num_rows_processed,num_missing_rows_skipped,num_iterations,variance_covariance from madlib.clinical_data_logreg) logreg" | gemfire --gemfire.pool.host-addresses="gemfire1-locator-0.gemfire1-locator.{{ session_namespace }}.svc.cluster.local:10334" --gemfire.region.regionName="clinicalDataModel" --gemfire.sink.json="true" --gemfire.sink.keyExpression="1"
```