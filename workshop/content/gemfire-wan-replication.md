### WAN Replication
Now, we will demonstrate the same multi-site replication across geographically distributed regions, i.e. **WAN Replication**. Tanzu Gemfire 
provides robust, native support for WAN replication. The deployment process will be mostly identical,
except that we will need to define **remote-locators** which each cluster will use for discovering remote sites to potentially connect to. 

This will be a topology whereby a primary site in one region is configured for one-way replication to a secondary readonly site 
in a different region. 
Other topologies such as **ring** and **full-mesh** are also supported. 

First, deploy the Gemfire **operator**. <b><font color="red">Only required if the operator was not already pre-installed.</font></b>
```execute
clear && kubectl create ns gemfire-system --dry-run -o yaml | kubectl apply -f - &&  kubectl create secret docker-registry image-pull-secret --namespace=gemfire-system --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && kubectl create secret docker-registry image-pull-secret --namespace={{session_namespace}} --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply -f - && helm uninstall  gemfire --namespace gemfire-system; helm install gemfire ~/other/resources/gemfire/gemfire-operator-{{DATA_E2E_GEMFIRE_OPERATOR_VERSION}}/ --namespace gemfire-system
```

Here is the configuration for the primary site: 
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml
text: "jvmOptions"
after: 2
```

#### Set up cross-cluster communication via Istio Gateway on the primary site, including remote locator information
In order to allow sites from remote networks to connect, there needs to be some kind of infrastructure in place that will allow cross-regional communication.
Here, we will use **Istio Gateway** to set up a LoadBalancer entrypoint at the cluster's edge. Here is the gateway's manifest:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-istio-primary.yaml
```

Deploy the Primary site with the Istio Gateway:
```execute
(kubectl get secret kconfig -n default -o jsonpath="{.data.myfile}" | base64 --decode) > mykubeconfig; kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; export ISTIO_INGRESS_HOST_SECONDARY=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig=mykubeconfig); export ISTIO_DNS_SECONDARY=$(kubectl -n kube-system get service kube-dns-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig mykubeconfig | awk '{ print $1; exit }'); kubectl config use-context eduk8s;  sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g; s/SECONDARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_DNS_SECONDARY}/g" ~/other/resources/gemfire/gemfire-istio-dns-primary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-dns-primary.yaml; kubectl rollout restart -n kube-system deployment/coredns; sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-istio-primary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-primary.yaml -n {{ session_namespace }}; export ISTIO_INGRESS_HOST_PRIMARY=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; export ISTIO_INGRESS_HOST_SECONDARY=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig=mykubeconfig); sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_PRIMARY}/g;s/SECONDARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_SECONDARY}/g;s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_SECONDARY[10334]/g;s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml; kubectl config use-context eduk8s; kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml 
```

View the update:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-sender-primary.yaml
```

#### Deploy the secondary cluster with the Gateway Receiver, Istio Gateway and up-to-date remote locator information
Next, we will create a Gemfire Cluster in our secondary site:
```editor:select-matching-text
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml
text: "remote-locators"
```

Notice the line with the **remote-locators** field. This will provide the locators for the Primary region, which the Secondary site will query to find out about 
connected Gateway Sender, Async Event Queues etc. 

Update the **remote-locators** field with the locator info for the Primary site:
```execute
sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_PRIMARY}/g;s/SECONDARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_SECONDARY}/g;s/#remote-locators:/remote-locators: $ISTIO_INGRESS_HOST_PRIMARY[10334]/g;s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml
```

View the update:
```editor:open-file
file: ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml
```

Deploy the Secondary site. (<font color="red">NOTE: Click **Ctrl-C** after the locator and server nodes show up as Ready:</font>)
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl delete gemfirecluster --all -n gemfire-remote --kubeconfig mykubeconfig || true; kubectl delete --force pvc --all -n gemfire-remote --kubeconfig mykubeconfig || true; kubectl delete virtualservice --all -n gemfire-remote --kubeconfig mykubeconfig || true; kubectl delete gateway --all -n gemfire-remote --kubeconfig mykubeconfig || true; kubectl create ns gemfire-remote --kubeconfig mykubeconfig || true;  kubectl config use-context eduk8s; export ISTIO_DNS_PRIMARY=$(kubectl -n kube-system get service kube-dns-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | awk '{ print $1; exit }'); sed -i "s/YOUR_SESSION_NAMESPACE/{{session_namespace}}/g;s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_DNS_PRIMARY}/g" ~/other/resources/gemfire/gemfire-istio-dns-secondary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-dns-secondary.yaml --kubeconfig mykubeconfig; kubectl rollout restart -n kube-system deployment/coredns --kubeconfig mykubeconfig; sed -i "s/YOUR_SESSION_NAMESPACE/{{session_namespace}}/g" ~/other/resources/gemfire/gemfire-istio-secondary.yaml && kubectl apply -f ~/other/resources/gemfire/gemfire-istio-secondary.yaml  --namespace=gemfire-remote --kubeconfig=mykubeconfig;  kubectl create secret docker-registry image-pull-secret --namespace=gemfire-remote --docker-server=registry.pivotal.io --docker-username='{{ DATA_E2E_PIVOTAL_REGISTRY_USERNAME }}' --docker-password='{{ DATA_E2E_PIVOTAL_REGISTRY_PASSWORD }}' --dry-run -o yaml | kubectl apply --kubeconfig=mykubeconfig -f - && kubectl apply -f ~/other/resources/gemfire/gemfire-cluster-with-gateway-receiver-secondary.yaml --namespace=gemfire-remote --kubeconfig=mykubeconfig; watch kubectl get pods -n gemfire-remote --kubeconfig=mykubeconfig; kubectl config use-context eduk8s
```

Create the **GatewayReceiver**:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "destroy gateway-receiver" || true; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "create gateway-receiver --start-port=13000 --end-port=13005 --hostname-for-senders=$ISTIO_INGRESS_HOST_SECONDARY" -e "set variable --name=APP_RESULT_VIEWER --value=900000"; kubectl config use-context eduk8s
```

Show the list of configured gateways:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=900000" -e "list gateways"; kubectl config use-context eduk8s
```

#### Configure the Gateway Sender with up-to-date remote locator information 
#### **NOTE: as a best practice, should start after Gateway Receiver**
Configure the **GatewaySender** in the **Primary** site:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create gateway-sender --id=sender1 --parallel=true --remote-distributed-system-id=21"
```

Show the list of configured gateways on the sender side:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=900000" -e "list gateways"
```

Similarly, re-display the list of configured gateways on the receiver side:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=900000" -e "list gateways"; kubectl config use-context eduk8s
```

#### Deploy the CacheListener for Oracle Write-Behind
Tanzu Gemfire supports event handling for various event-generating operations: region updates, new cache entries, etc.
Here, we will implement the **CacheAsyncListener** adapter to asynchronously update a backend Oracle database when the **claims** region is updated.
This will occur in both the primary and secondary sites, hence enabling an active-active Oracle setup. 

Here is the **CacheAsyncListener** to be deployed:
```editor:select-matching-text
file: ~/other/resources/gemfire/java-source/src/main/java/com/vmware/multisite/SyncOracleCacheAsyncListener.java
text: "@Override"
after: 19
```

Build the **CacheAsyncListener** jar file for the **primary** site, and deploy it to the primary cluster:
```execute
cd ~/other/resources/gemfire/java-source; ./mvnw -s settings.xml clean dependency:copy-dependencies -DoutputDirectory=target/lib -DincludeGroupIds=org.apache.commons,com.google.code.gson,org.apache.logging.log4j,org.slf4j,com.oracle.ojdbc,commons-dbutils package -Ddemo.resources.dir=src/main/resources/primary; cd -; kubectl cp ~/other/resources/gemfire/java-source/target/lib  {{ session_namespace }}/gemfire0-locator-0:/tmp; kubectl cp ~/other/resources/gemfire/java-source/target/gemfire-multisite-poc-1.0-SNAPSHOT.jar  {{ session_namespace }}/gemfire0-locator-0:/tmp/lib; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "deploy --dir=/tmp/lib"
```

After adding the **CacheAsyncListener** to the cluster's classpath, let's create an **async queue** - the listener will process events from this queue:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-server-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create async-event-queue --id=primaryAsyncQueue --persistent --listener=com.vmware.multisite.SyncOracleCacheAsyncListener"; kubectl -n {{ session_namespace }} exec -it gemfire0-locator-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=900000" -e "list async-event-queues"
```


Now, we can register it with the **claims** region:
```execute
kubectl -n {{ session_namespace }} exec -it gemfire0-server-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create region --name=claims --type=PARTITION --async-event-queue-id=primaryAsyncQueue --gateway-sender-id=sender1"
```

Similarly, build the **CacheListener** jar file for the **secondary** site and deploy to the secondary cluster:
```execute
cd ~/other/resources/gemfire/java-source; ./mvnw -s settings.xml clean dependency:copy-dependencies -DoutputDirectory=target/lib -DincludeGroupIds=org.apache.commons,com.google.code.gson,org.apache.logging.log4j,org.slf4j,com.oracle.ojdbc,commons-dbutils package -Ddemo.resources.dir=src/main/resources/secondary; cd -; kubectl cp ~/other/resources/gemfire/java-source/target/lib  gemfire-remote/gemfire0remote-locator-0:/tmp --kubeconfig mykubeconfig; kubectl cp ~/other/resources/gemfire/java-source/target/gemfire-multisite-poc-1.0-SNAPSHOT.jar  gemfire-remote/gemfire0remote-locator-0:/tmp/lib --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "deploy --dir=/tmp/lib"; kubectl config use-context eduk8s
```

Create an **async queue** for the listener:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-server-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "create async-event-queue --id=secondaryAsyncQueue --persistent --listener=com.vmware.multisite.SyncOracleCacheAsyncListener"; kubectl -n gemfire-remote exec -it gemfire0remote-locator-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "set variable --name=APP_RESULT_VIEWER --value=900000" -e "list async-event-queues"; kubectl config use-context eduk8s
```

Register the **CacheListener** with the **claims** region in the **secondary** site:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl -n gemfire-remote exec -it gemfire0remote-server-0 --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "create region --name=claims --type=PARTITION --async-event-queue-id=secondaryAsyncQueue"; kubectl config use-context eduk8s
```

#### Demo: Unidirectional write
View the associated Oracle database (can use DBeaver, or launch CloudBeaver here:).
```dashboard:open-url
name: CloudBeaver
url: https://demo.cloudbeaver.io/#/
```

In CloudBeaver, first set up the data sources for each site:
```execute
echo Primary DB URL: ${DATA_E2E_ORACLE_DB_PRIMARY_URL} \nSecondary DB URL: ${DATA_E2E_ORACLE_DB_SECONDARY_URL}
```

In CloudBeaver, launch the **SQL** tab and execute the following:
```copy
TRUNCATE TABLE ADMIN.claims;
```

<b>Observe that the relevant tables are empty.</b>

Deploy the Dashboard apps:
```execute
sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_PRIMARY}/g; s/SECONDARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_SECONDARY}/g" ~/other/resources/gemfire/wan-dashboard-primary.yaml; sed -i "s/PRIMARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_PRIMARY}/g; s/SECONDARY_ISTIO_INGRESS_HOSTNAME/${ISTIO_INGRESS_HOST_SECONDARY}/g" ~/other/resources/gemfire/wan-dashboard-secondary.yaml; kubectl -n {{ session_namespace }} exec -it gemfire0-server-0 -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire/v1" -e "create region --name=sticky --type=REPLICATE" -e "put --key='bit' --value='PRIMARY_URL' --region=sticky"; kubectl delete deployment primary-dashboard || true; kubectl apply -f ~/other/resources/gemfire/wan-dashboard-primary.yaml; export DASHBOARD_PRIMARY=$(kubectl get service primary-dashboard-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl delete deployment secondary-dashboard -n gemfire-remote --kubeconfig mykubeconfig || true; kubectl apply -f ~/other/resources/gemfire/wan-dashboard-secondary.yaml -n gemfire-remote  --kubeconfig mykubeconfig; kubectl exec -it gemfire0remote-server-0 -n gemfire-remote --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "create region --name=sticky --type=REPLICATE" -e "put --key='bit' --value='SECONDARY_URL' --region=sticky" --kubeconfig mykubeconfig; export DASHBOARD_SECONDARY=$(kubectl get service secondary-dashboard-svc -n gemfire-remote  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig mykubeconfig); kubectl config use-context eduk8s
```

Launch the random data generator for the **primary** side.
```execute
cd ~/other/resources/gemfire/python-source/; python -m app.random_claim_generator -1 -1 http://$ISTIO_INGRESS_HOST_PRIMARY:7070/gemfire-api/v1/claims 'primary'; cd -
```

Launch the Dashboard app for the **primary** side:
```execute
echo http://${DASHBOARD_PRIMARY}:8080/
```

Launch the Pulse app for the **primary** side:
```execute
echo http://${ISTIO_INGRESS_HOST_PRIMARY}:7070/pulse/
```

<font color="red">NOTE: Click CTRL-C after a few seconds.</font>

View the associated Oracle database (can use DBeaver).

Launch the Dashboard app for the **secondary** side:
```execute
echo http://${DASHBOARD_SECONDARY}:8080/
```

Launch the Pulse app for the **secondary** side:
```execute
echo http://${ISTIO_INGRESS_HOST_SECONDARY}:7070/pulse/
```

View the associated oracle database (can use DBeaver or CloudBeaver).

Now, kill one of the gemfire pods on the secondary side and switch the secondary dashboard over to the primary site:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl exec -it gemfire0remote-server-0 -n gemfire-remote --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "put --key='bit' --value='PRIMARY_URL' --region=sticky"; kubectl delete pod gemfire0remote-server-0 -ngemfire-remote --kubeconfig mykubeconfig; kubectl config use-context eduk8s
```

After a few moments, switch back to the secondary site - observe no data loss:
```execute
kubectl config use-context secondary-ctx --kubeconfig mykubeconfig; kubectl exec -it gemfire0remote-server-0 -n gemfire-remote --kubeconfig mykubeconfig -- gfsh -e "connect --url=http://$ISTIO_INGRESS_HOST_SECONDARY:7070/gemfire/v1" -e "put --key='bit' --value='SECONDARY_URL' --region=sticky"; kubectl config use-context eduk8s
```