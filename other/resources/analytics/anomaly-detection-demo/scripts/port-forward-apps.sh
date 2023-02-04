export ANOMALY_POD_NAME=$(kubectl get pods --namespace streamlit -l "app=streamlit-dashboard-arima" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $ANOMALY_POD_NAME 8091:8501 -nstreamlit &

export ANOMALY_RNN_POD_NAME=$(kubectl get pods --namespace streamlit -l "app=streamlit-dashboard-rnn" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $ANOMALY_RNN_POD_NAME 8092:8501 -nstreamlit &
