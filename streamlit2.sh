kubectl delete -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-bindings.yaml -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-bindings.yaml -nstreamlit

kubectl delete deploy streamlit-dashboard-arima -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/dashboard-staging-arima.yaml -nstreamlit

kubectl delete deploy streamlit-dashboard-rnn -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/dashboard-staging-rnn.yaml -nstreamlit
watch kubectl get all -n streamlit