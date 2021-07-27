### Data Analytics

<font color="red">In **Jupyter**, run the *Training: Run logistic regression training results from Greenplum* cell.</font>.

<font color="red">In **Jupyter**, run the *Model Selection: View model metrics* cell.</font>

<font color="green">Use the Gemfire API to predict the classification for a set of sample inputs in Jupyter. When running the cell *Get latest model*, use this as the hostname:</font>
```execute
kubectl get svc gemfire1-dev-api -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

Deploy the Petclinic Analytics App:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/petclinic-analytics/petclinic-analytics-app.yaml && kubectl apply -f ~/other/resources/petclinic-analytics/petclinic-analytics-app.yaml
```

View the Petclinic Analytics App:
```dashboard:reload-dashboard
name: Petclinic
url:  "{{ingress_protocol}}://petclinic-analytics-{{session_namespace}}.{{ingress_domain}}/"
```