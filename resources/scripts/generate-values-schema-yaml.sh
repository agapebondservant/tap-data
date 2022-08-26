cat > resources/mlflow-values-schema.yaml <<- EOF
#@data/values-schema
---
#@schema/desc "Region"
#@schema/type any=True
region:

#@schema/desc "S3-compatible artifact store"
#@schema/type any=True
artifact_store:

#@schema/desc "S3-compatible store access key"
#@schema/type any=True
access_key:

#@schema/desc "S3-compatible store secret key"
#@schema/type any=True
secret_key:

#@schema/desc "MLFlow on Tanzu version"
version: 1.0.0

#@schema/desc "DB backing store"
backing_store: "sqlite:///my.db"

#@schema/desc "Ingress FQDN"
#@schema/type any=True
ingress_fqdn:

#@schema/desc "S3-compatible store bucket"
bucket: mlflow

#@schema/desc "Ignore TLS flag"
ignore_tls: "true"

#@schema/desc "MLFlow Tracking Server Ingress Domain"
#@schema/type any=True
ingress_domain:
EOF