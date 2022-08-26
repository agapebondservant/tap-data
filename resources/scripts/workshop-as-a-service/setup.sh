#!/bin/bash

########################################################
# Prepare environment
########################################################
resources/scripts/workshop-as-a-service/prepare-env.sh

########################################################
# Update K8s cluster configuration which will
# - setup ConfigMap with environment variables
# - Deploy default storage class
# - Configure network policy
# Argument 1: Name of default storage class
########################################################
resources/scripts/workshop-as-a-service/update-k8s-cluster-defaults.sh 'generic'

########################################################
# Setup dependencies
########################################################
resources/scripts/workshop-as-a-service/setup-dependencies.sh

########################################################
# Operators: Install GREENPLUM
########################################################
resources/scripts/workshop-as-a-service/setup-greenplum.sh

########################################################
# Operators: Install RABBITMQ
########################################################
resources/scripts/workshop-as-a-service/setup-rabbitmq.sh

########################################################
# Operators: Install GEMFIRE
########################################################

########################################################
# Operators: Install POSTGRES
########################################################
resources/scripts/workshop-as-a-service/setup-postgres.sh

########################################################
# Operators: Install MYSQL
########################################################
resources/scripts/workshop-as-a-service/setup-mysql.sh

########################################################
# Package: Install SPRING CLOUD DATA FLOW
########################################################
resources/scripts/workshop-as-a-service/setup-scdf-carvel.sh

########################################################
# Apps: Install Operator UI
########################################################
resources/scripts/workshop-as-a-service/setup-operator-ui.sh

########################################################
# Workshops: Deploy Tanzu Postgres for Kubernetes workshop
########################################################


########################################################
# Workshops: Deploy Tanzu RabbitMQ commercial features
########################################################

########################################################
# Workshops: Deploy Tanzu MySQL for Kubernetes workshop
########################################################

