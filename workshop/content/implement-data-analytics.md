### Data Analytics



Now, generate a **logistic regression** model from the data via **MADLib**:
<font color="green">In **Jupyter**, run the *Training: Run logistic regression training in Greenplum* cell.</b></font>

<font color="green">When running the cell *Get latest model*, use this as the hostname:</font>
```execute
kubectl get svc gemfire1-dev-api -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```
