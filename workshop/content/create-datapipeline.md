
### Overview

Let's proceed to  create a pipeline  with a Greenplum **source** and a Gemfire **sink**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:reload-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}/dashboard
```

Here is the pipeline we will be creating:
```copy
jdbc --spring.datasource.url="jdbc:postgresql://greenplum.greenplum-system.svc.cluster.local:5432/gpadmin" --spring.datasource.username="gpadmin" --spring.datasource.password="changeme" --jdbc.supplier.query="select row_to_json(logreg) from (select coef, log_likelihood, std_err,z_stats,p_values,odds_ratios,num_rows_processed,num_missing_rows_skipped,num_iterations,variance_covariance from madlib.clinical_data_logreg) logreg" | gemfire --gemfire.pool.host-addresses="gemfire1-locator-0.gemfire1-locator.data-samples-w01-s007.svc.cluster.local:10334" --gemfire.region.regionName="clinicalDataModel" --gemfire.sink.json="true" --gemfire.sink.keyExpression="new SimpleDateFormat(‘yyyyMMddHHmm’).format(new Date())"
```

Let's view the RabbitMQ console for the broker that will be leveraged by our pipelines - login with <i>admin/admin:</i>

```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbitmain.tanzudata.ml/dashboard
```

Restore the UI for the other RabbitMQ cluster we created earlier.
```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbit{{ session_namespace }}.{{ ingress_domain }}
```

Now we should be able to view our data in our Gemfire region:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire1-locator-0 -- gfsh
```

Connect  to the local Gemfire cluster:
```execute
connect
```

Run a query to view the data in our region: <font color="red">NOTE: You can also use autocomplete.
```execute
query --query="select row_to_json.value from /clinicalDataModel"
```

Next, we will build our real-time scoring interface and analytics dashboard.
