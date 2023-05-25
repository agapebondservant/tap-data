### Rapid-fire Demo

#### Anomaly Detection App
View the app:
```dashboard:open-url
url: http://demo-ui.{{ ingress_domain }}
```

#### Management Consoles
View the RabbitMQ console:
```dashboard:open-url
url: http://rmqanomaly.{{ ingress_domain }}
```

Use the credentials below to login:
```execute
kubectl get secret rmqanomaly-default-user -o jsonpath="{.data.default_user\.conf}" -n anomaly-ns | base64 --decode
```

Use the password below to login (username is admin):
```execute
kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode
```

View the Grafana Dashboard for the RabbitMQ cluster:
```dashboard:open-url
url: http://grafana.{{ ingress_domain }}
```

View the Wavefront Dashboard for the RabbitMQ cluster:
```dashboard:open-url
url: {{ DATA_E2E_WAVEFRONT_RABBIT_DASHBOARD_URL }}
```

View the Gemfire Pulse console: (login: admin/admin)
```dashboard:open-url
url: http://gfanomaly-locator.{{ ingress_domain }}/pulse
```

(Optional) View the Wavefront Dashboard for the Gemfire cluster:
```dashboard:open-url
url: {{ DATA_E2E_WAVEFRONT_GEMFIRE_DASHBOARD_URL }}
```

View the Greenplum Command Center:
```dashboard:open-url
url: http://ec2-44-201-91-88.compute-1.amazonaws.com:28080/
```

Use the password below to login (username is gpmon):
```execute
echo Uu4jcDSjqlDVQ
```

View Spring Cloud Data Flow pipeline:
```dashboard:open-url
url: http://scdf.{{ ingress_domain }}/dashboard
```

If necessary, create the pipeline by copying the following:
```execute
echo greenplum-training=jdbc --spring.datasource.url=\"{{DATA_E2E_ML_TRAINING_DB_CONNECT}}\" --spring.datasource.username=\"gpadmin\" --spring.datasource.password=\"Uu4jcDSjqlDVQ\" --jdbc.supplier.query=\"select row_to_json\(randomforest\) from \(select id, time_elapsed, amt, lat, long, is_fraud from public.rf_credit_card_transactions_inference limit 100\) randomforest\" \| gemfire --gemfire.pool.host-addresses=\"gfanomaly-locator-0.gfanomaly-locator.anomaly-ns.svc.cluster.local:10334\" --gemfire.region.regionName=\"mds-region-greenplum\" --gemfire.sink.json=\"true\" --gemfire.sink.keyExpression=\"1\"
```

View the Data Services Manager console: (credentials: provider@vmware.com/VMware1!):
```dashboard:open-url
url: https://10.202.24.16/login
```

View Rabbit cluster manifest to deploy:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster.yaml
```

Demonstrate Rabbit cluster deployment:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-monitor.yaml -nmonitoring-tools; kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-operator-monitor.yaml -nmonitoring-tools; kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-data-demo.yaml -n anomaly-ns
```

View Gemfire cluster manifest to deploy:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-cluster-data-demo.yaml
```

Demonstrate Gemfire cluster deployment:
```execute
kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-data-demo.yaml -n anomaly-ns
```