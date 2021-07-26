### Data Analytics

<font color="red">In **Jupyter**, run the *Training: Run logistic regression training results from Greenplum* cell.</font>.

<font color="red">In **Jupyter**, run the *Model Selection: View model metrics* cell.</font>

<font color="green">Use the Gemfire API to predict the classification for a set of sample inputs in Jupyter. When running the cell *Get latest model*, use this as the hostname:</font>
```execute
kubectl get svc gemfire1-dev-api -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```
