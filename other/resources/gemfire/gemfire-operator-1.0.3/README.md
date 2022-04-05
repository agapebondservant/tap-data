# GemFire Operator

Prerequisites:
- Kubernetes 1.14+ cluster with [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) configured to access the cluster
- [Helm](https://helm.sh/) 3
- Access to [Dev Registry](https://dev.registry.pivotal.io/) (aka Harbor)
  - Use your credentials to Tanzu Network (formerly Pivotal Network)
  - If the "tanzu-gemfire-for-kubernetes" project is not visible, please reach out to [#caching-k8s](https://pivotal.slack.com/archives/CP69JDRQ9) to get access

> Note: Replace \<USERNAME\> and \<PASSWORD\> in all of the commands below with your Dev Registry credentials.

Login to the Dev Registry.
```shell script
helm registry login dev.registry.pivotal.io \
  --username <USERNAME> \
  --password <PASSWORD> 
```

Pull the `gemfire-operator` Helm chart. Optionally specify the output directory with `--destination <OUTPUT DIRECTORY>`.
> Note: Replace \<VERSION\> with a tagged version of the Helm chart.
```shell script
export HELM_EXPERIMENTAL_OCI=1
helm pull oci://dev.registry.pivotal.io/tanzu-gemfire-for-kubernetes/gemfire-operator --version=<VERSION> --untar

```

Install a GemFire cluster using the chart from Dev Registry to the default namespace on your Kubernetes cluster.
```shell script
helm install gemfire-operator <PATH_TO_EXPORTED_DIRECTORY> --namespace gemfire-system \
  --set 'registry.server=dev.registry.pivotal.io,registry.username=<USERNAME>,registry.password=<PASSWORD>'
```

To verify that the operator has been installed, run `helm ls`. The output should look like the following:
```
NAME                        NAMESPACE       STATUS      CHART
gemfire-operator	gemfire-system  deployed	gemfire-operator-0.0.1-alpha2
```

To uninstall the operator, first uninstall any GemFire clusters and then run `helm uninstall gemfire-operator --namespace gemfire-system`.
