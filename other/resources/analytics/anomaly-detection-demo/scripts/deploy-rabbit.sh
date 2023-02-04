kubectl delete -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-topology.yaml -n streamlit
kubectl delete -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-cluster.yaml -nstreamlit

kubectl apply -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-cluster.yaml -nstreamlit
kubectl apply -f other/resources/analytics/anomaly-detection-demo/rabbitmq-analytics-topology.yaml -n streamlit
watch kubectl get all -n streamlit
