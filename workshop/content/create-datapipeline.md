
### Overview

Let's proceed to  create a pipeline  with a Greenplum **source** and a Gemfire **sink**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:reload-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}/dashboard
```

Here is the pipeline we will be creating:
```copy
jdbc --spring.datasource.url="jdbc:postgresql://greenplum.greenplum-system.svc.cluster.local:5432/gpadmin" --spring.datasource.username="gpadmin" --spring.datasource.password="changeme" --jdbc.supplier.query="select row_to_json(logreg) from (select coef, log_likelihood, std_err,z_stats,p_values,odds_ratios,num_rows_processed,num_missing_rows_skipped,num_iterations,variance_covariance from madlib.clinical_data_logreg) logreg" | gemfire --gemfire.pool.host-addresses="gemfire1-locator-0.gemfire1-locator.{{ session_namespace }}.svc.cluster.local:10334" --gemfire.region.regionName="clinicalDataModel" --gemfire.sink.json="true" --gemfire.sink.keyExpression="1"
```

Let's view the RabbitMQ console for the broker that will be leveraged by our pipelines - login with <i>user/CHANGEME:</i>

```dashboard:reload-dashboard
name: RabbitMQ
url: {{ ingress_protocol }}://rabbitmain.{{ DATA_E2E_BASE_URL }}
```

Use the following credentials to login to the RabbitMQ Management console:
```execute
printf "Username: $(kubectl get secret rabbitmq -o jsonpath='{.data.rabbitmq-erlang-cookie}' |base64  --decode)\nPassword: $(kubectl get secret rabbitmq -o jsonpath='{.data.rabbitmq-password}' |base64  --decode)\n"
```

<font color="red">Reload the Management UI for the other RabbitMQ cluster we created earlier, if necessary:</font>
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

Run a query to view the data in our region: <font color="red">NOTE: You can also use autocomplete.</font>
```execute
query --query="select row_to_json.value from /clinicalDataModel"
```

Next, we will build our real-time scoring interface and analytics dashboard.

Exit the **gfsh** shell:
```execute
exit
```