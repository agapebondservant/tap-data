kubectl get all -o name -n streamlit | xargs kubectl delete -n streamlit

kubectl delete configmap streamlit-env -n streamlit || true
kubectl create configmap streamlit-env --from-env-file=other/resources/analytics/anomaly-detection-demo/.env-properties -n streamlit

kubectl delete -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-bindings.yaml -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-bindings.yaml -nstreamlit

kubectl delete deploy streamlit-dashboard-arima -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/dashboard-staging-arima.yaml -nstreamlit

kubectl delete deploy streamlit-dashboard-rnn -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/dashboard-staging-rnn.yaml -nstreamlit
watch kubectl get all -n streamlit