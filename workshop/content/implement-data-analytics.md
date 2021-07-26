### Data Analytics

Invoke the newly deployed API for retrieving the **logistic regression** model via Gemfire:
```dashboard:create-dashboard
name: Gemfire
url: $(ingress_protocol)://$(session_namespace)-gemfire1-dev-api.$(ingress_domain)/geode/v1/clinicalDataModel
```

<font color="green">Use the Gemfire API to predict the classification for a set of sample inputs in Jupyter. When running the cell *Get latest model*, use this as the hostname:</font>
```execute
kubectl get svc gemfire1-dev-api -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```
