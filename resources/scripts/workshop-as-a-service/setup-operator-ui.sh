#!/bin/bash

# echo "Installing Operator UI..."

# kubectl create namespace operator-ui
# kubectl create configmap kconfig --from-file </path/to/multicluster/kubeconfig> --namespace operator-ui
# other/resources/operator-ui/annotate.sh
# kubectl apply -f other/resources/operator-ui/overlays.yaml
# kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-app.yaml --namespace operator-ui
# kubectl annotate pkgi <RABBITMQ_PKGI_NAME> ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=rabbitmq-operator-tsqlui-annotation-overlay-secret -n<RABBITMQ_PKGI_NAMESPACE> --overwrite
# kubectl annotate pkgi <POSTGRES_PKGI_NAME> ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=postgres-operator-tsqlui-annotation-overlay-secret -n<POSTGRES_PKGI_NAMESPACE> --overwrite
# kubectl apply -f other/resources/operator-ui/tanzu-operator-ui-httpproxy.yaml --namespace operator-ui

# echo "Operator UI installed."