
#### Monitoring Postgres Data (ctd)
Tanzu Postgres provides a set of scrapeable Prometheus endpoints whose metrics can be collected and forwarded to any OpenMetrics backend.

Let's demonstrate this using **Datadog** and **Wavefront**.

##### <i>With Datadog:</i>
Set up the Datadog agent for Kubernetes with Prometheus Autodiscovery enabled:
```editor:open-file
file: ~/other/resources/datadog/data-dog.yaml
```

Deploy the Datadog agent:
```execute
helm install datadog -f ~/other/resources/datadog/data-dog.yaml --set datadog.site='datadoghq.com' --set datadog.apiKey='{{DATA_E2E_DATADOG_API_KEY}}' datadog/datadog
```

View the Postgres dashboard:
```dashboard:open-url
url: https://app.datadoghq.com/screen/integration/235/postgres---overview?_gl=1*1rkgt2o*_gcl_aw*R0NMLjE2NDUyMTkzNTEuQ2owS0NRaUFwTDJRQmhDOEFSSXNBR01tLUtINlZnZ0dZelhOSTdadV8zNlBLMENHbFpjQS1TX2FmOG40ck1zSEVrTXVFa2RpZFB5RnI4UWFBanozRUFMd193Y0I.*_ga*MTI3MDQ4ODI1OC4xNjQ1MTQwNDky*_ga_KN80RDFSQK*MTY0NTgyNDU3NC42LjEuMTY0NTgyNTAxMC4w&_ga=2.68643028.418082025.1645749670-1270488258.1645140492&_gac=1.251689211.1645219351.Cj0KCQiApL2QBhC8ARIsAGMm-KH6VggGYzXNI7Zu_36PK0CGlZcA-S_af8n4rMsHEkMuEkdidPyFr8QaAjz3EALw_wcB
```

(NOTE: When prompted, use the credentials below to login:)
```execute
printf "Username: {{DATA_E2E_DATADOG_USER}}\nPassword:{{DATA_E2E_DATADOG_PASSWORD}}
```

##### <i>With Wavefront:</i>

#### Secret Management with Vault
