#!/bin/bash

########################################################################
# Setup variables
#########################################################################
[ ! -z "$1" ] && storageclassvar=$1 || storageclassvar='generic'

########################################################################
# Setup ConfigMap
#########################################################################
echo "Creating ConfigMap for environment variables..."
kubectl delete configmap data-e2e-env || true
sed 's/export //g' .env > .env-properties
kubectl create configmap data-e2e-env --from-env-file=.env-properties
rm .env-properties
echo "ConfigMap created."

########################################################################
# Storage Class
# (Note: this assumes that the volume binding mode is WaitForFirstCustomer instead of Immediate,
# and the reclaimPolicy should be Retain)
#########################################################################
echo "Creating StorageClass..."
kubectl apply -f resources/storageclass.yaml
kubectl patch storageclass $storageclassvar -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
echo "StorageClass created."

########################################################################
# Network Policy
# (Note: assumes allow-all-ingress permissions)
#########################################################################
echo "Creating NetworkPolicy..."
kubectl apply -f resources/networkpolicy.yaml
echo "NetworkPolicy created."

########################################################################
# Pod Security Policy
#########################################################################
echo "Creating PodSecurityPolicy..."
kubectl apply -f resources/podsecuritypolicy.yaml
echo "PodSecurityPolicy created."