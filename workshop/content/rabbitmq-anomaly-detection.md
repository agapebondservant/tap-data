### Anomaly Detection Demo

First, run the Jupyter notebooks entitled **Airline Analytics (ARIMA)** and **Airline Analytics (RNN)**.

Next, show the **User Experience** dashboard app:
```dashboard:create-dashboard
name: Anomalies
url: {{ ingress_protocol }}://anomaly-dashboard.{{ DATA_E2E_BASE_URL }}:8080
```

Next, show the MLFlow site:

Next, show the Spring Cloud DataFlow dashboard:
```dashboard:create-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ ingress_domain }}/dashboard/#/streams/list
```

Next, show the Ray dashboard:
```dashboard:create-dashboard
name: Ray
url: {{ ingress_protocol }}://ray.tanzudatadev.ml/
```

Next, show GitHub Actions:
```dashboard:create-dashboard
name: GitHub
url: {{ ingress_protocol }}://github.com/agapebondservant/sample-ml-step/actions
```


