### Deploying Tanzu RabbitMQ - Commercial Features
![Tanzu RabbitMQ Commercial Features](images/tanzurabbit.png)
**Tanzu RabbitMQ** includes several enterprise-grade, commercial-only features.

Now we will cover the following:

#### Deploying via the Operator UI
With **Tanzu RabbitMQ**, brokers/clusters can be deployed by using the **Tanzu Operator UI**. First, refresh the UI settings to ensure that it is in sync with the latest Operator changes:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/operator-ui/tanzu-operator-ui-app.yaml && kubectl apply -f ~/other/resources/operator-ui/tanzu-operator-ui-app.yaml && cp ~/other/resources/operator-ui/cli/* /usr/bin/ && ~/other/resources/operator-ui/crd_annotations/apply-annotations
```

Now access the Operator UI:
```dashboard:open-url
url: http://operator-ui-{{ session_namespace }}.{{ ingress_domain }}
```

#### Inter-node Data Compression
**Tanzu RabbitMQ** provides out-of-the-box compression for traffic between nodes, as well as client-to-node traffic.
This feature is enabled by default with **Tanzu RabbitMQ**.
This can be especially beneficial with high-traffic workloads, or multi-site workloads where bandwidth across sites can be costly.
With **inter-node data compression**, bandwidth is reduced by orders of magnitude, which can result in significant cost savings.

To demonstrate this, first configure an **uncompressed** cluster (using FOSS RabbitMQ):
```editor:select-matching-text
file: ~/other/resources/rabbitmq/rabbitmq-cluster-uncompressed.yaml
text: "image:"
```

Deploy the uncompressed cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-uncompressed.yaml
```

Generate data on the uncompressed cluster. For this, we will use RabbitMQ's throughput testing tool, **PerfTest**. Deploy an instance of PerfTest:
```execute
kubectl wait --for=condition=Ready pod/rabbitcluster-uncompressed-server-2 -n {{ session_namespace }} && kubectl delete deploy perftest || true; kubectl create deploy perftest --image=pivotalrabbitmq/perf-test:2.18.0 -- sleep 10000
```

Once the deployment shows as ready (in the lower console), launch the PerfTest shell. <font color="red"><b>NOTE:</b> Wait until all 3 nodes of the uncompressed cluster are in <b>Ready</b> status:</font>
```execute
kubectl exec deploy/perftest -it -- sh
```

Using PerfTest, publish messages to a quorum queue on the uncompressed cluster - wait for a few seconds for the job to complete:
```execute
bin/runjava com.rabbitmq.perf.PerfTest --uri amqp://test-user:test-password@rabbitcluster-uncompressed --producers 10 --consumers 0  --routing-key "uncompressed" -pmessages 40000 --rate 5000 --quorum-queue --queue "uncompressed"
```

Navigate to the Grafana site: select the **Erlang Distribution** dashboard, select **rabbitcluster-uncompressed** from the cluster dropdown,  and view the **"Data sent to peer node /s"** widget:
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

Back on the Perftest shell: exit the shell:
```execute
exit
```

Now, configure a Tanzu RabbitMQ cluster, which enables inter-node compression by default:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-compressed.yaml
```

Deploy the compressed cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-compressed.yaml
```

Relaunch the PerfTest shell. This will take a few seconds to execute. <font color="red"><b>NOTE:</b> Wait until all 3 nodes of the compressed cluster are in <b>Ready</b> status:</font>
```execute
sleep 10; kubectl wait --for=condition=Ready pod/rabbitcluster-compressed-server-0 -n {{ session_namespace }} && kubectl exec deploy/perftest -it -- sh
```

Generate data on the compressed cluster - wait for a few seconds for the job to complete:
```execute
bin/runjava com.rabbitmq.perf.PerfTest --uri amqp://test-user:test-password@rabbitcluster-compressed --producers 10 --consumers 0 --routing-key "compressed" -pmessages 40000 --rate 5000 --quorum-queue --queue "compressed"
```

Navigate again to the Grafana site: select the **Erlang Distribution** dashboard, select **rabbitcluster-compressed** from the cluster dropdown, and view the **"Data sent to peer node /s"** widget (should be much less):
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

Back on the Perftest shell: then exit the shell:
```execute
exit
```

#### Standby Replication Operator

**Tanzu RabbitMQ** provides a streamlined approach for replication across sites with its **Standby Replication** plugins.
In Kubernetes, these are provided by the Standby Replication Operator. 
The Standby Replication Operator handles automated **schema** and **queue** replication to a hot standby cluster.

Without **Tanzu RabbitMQ**, standby replication can be achieved by manually importing the schema from the upstream and using 
one of RabbitMQ's core features for cross-broker/cross-site replication, such as **federation** or **shoveling**. 
However, the core RabbitMQ approach involves several manual steps, and relies on TTL/message throughput estimates for message synchronization 
between upstream and downstream, which can result in data loss and/or data duplication if the estimates were not accurate.
This is mitigated via the commercial **Standby Replication** feature, which uses streaming log updates for an up-to-date view of upstream messages,
and offers an API for automatic promotion of the standby during disaster recovery. Let's explore how.

##### Deploying Upstream and Downstream Clusters
First, we will create a new upstream cluster:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream.yaml
text: "additionalPlugins"
after: 9
```

Notice the **plugins** and **config** that are required for the upstream.

Deploy the upstream cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream.yaml -n {{ session_namespace }}
```

Next, we wil create the entities in the upstream that will be replicated to the downstream using the **Topology operator**.
The Topology operator handles the creation and management of the RabbitMQ entities that belong to a cluster,
such as queues, policies, exchanges, users, queue bindings.

Quorum queues are a newer type of queue which is more opinionated than classic queues when it comes to data safety and failure recovery.
As of RabbitMQ 3.8, they are the preferred approach for replicated queues.
Mirrored classic queues are still available for legacy purposes, but they will be retired at some point in the future,
so the recommendation is to use quorum queues for use cases where data safety is important.

Let's create a new **Quorum Queue** - here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-quorum-queue.yaml
```
Notice that the Quorum Queue is created in a vhost **test**. 
For an upstream vhost to be eligible for standby replication, it must exist prior to policy creation, and must have the **standby_replication** tag.

Let's deploy it:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-quorum-queue.yaml -n {{ session_namespace }}
```

Similarly, we create a new downstream cluster which will serve as the hot standby:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream.yaml
text: "additionalPlugins"
after: 11
```

Deploy the downstream cluster:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream.yaml -n {{ session_namespace }}
```

##### Configuring Schema Replication plugin (upstream)
Next, we will configure the **Schema Replication** plugin, which will take care of **schema replication**. 

First we configure the user that will be used to establish the connection to the upstream.
We do this configuring the user credentials and permissions:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-credsandpermissions.yaml
```

Deploy the new User with its credentials and permissions:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-credsandpermissions.yaml -n {{ session_namespace }}
```

Now we will configure the actual Schema Replication object, including setting up the **upstream endpoint** and **upstream cluster name**:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-schema-object.yaml
```

Deploy the Schema Replication object:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-schema-object.yaml && kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-schema-object.yaml -n {{ session_namespace }}
```

##### Configuring Schema Replication plugin (downstream)
Now that we have configured the upstream cluster, we will configure the downstream to receive replicated schema and messages from the upstream.
We will start with Schema Replication.
Similarly to before, we will configure the **Schema Replication** plugin for the downstream.


First, we will create a **schema replication** vhost in the downstream to match the upstream:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-vhost.yaml
```

Deploy the new Vhost:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-vhost.yaml
```

Next, we will configure the **Schema Replication** user and permissions as before.
Here is the manifest:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-credsandpermissions.yaml
```

Deploy the new downstream User with its credentials and permissions:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-credsandpermissions.yaml -n {{ session_namespace }}
```

Similarly, we will configure the **Schema Replication** object for the downstream:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-schema-object.yaml
```

Deploy the **Schema Replication** object:
```execute
sed -i "s/YOUR_SESSION_NAMESPACE/{{ session_namespace }}/g" ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-schema-object.yaml && kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-schema-object.yaml -n {{ session_namespace }}
```

After about 1 minute (*twice* the replication interval - 30 seconds by default), 
navigate to the Grafana website, select the **RabbitMQ-Overview** dashboard and observe that the queue is now replicated in the downstream site
(select **rabbitcluster-downstream1** from the cluster dropdown):
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

##### Configuring Standby Message Replication plugin (upstream)
After configuring the **Schema Replication** plugin, we will now configure the **Standby Message Replication** plugin,
which will take care of **queue replication** to the standby. In our case, we will reuse the User created for Schema Replication above.

We configure it by setting up a **replication policy** which will be used to replicate from the upstream:
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-message-object.yaml
```
Here, the replication policy will replicate *all* quorum queues from the **test** vhost.

Deploy the Standby Message Replication object:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-upstream-message-object.yaml -n {{ session_namespace }}
```

##### Configuring Standby Message Replication plugin (downstream)

Similarly, we will configure the **Standby Message Replication** plugin for the downstream.
```editor:open-file
file: ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-message-object.yaml
```

Deploy the Standby Message Replication object:
```execute
kubectl apply -f ~/other/resources/rabbitmq/rabbitmq-cluster-standbyreplication-downstream-message-object.yaml -n {{ session_namespace }}
```

##### Testing
Now, we will test that the schema replication is working as expected. 
First, we will identify the node where downstream replication was orchestrated:
```execute
for tmp_pod in $(kubectl get pod -l app.kubernetes.io/name=rabbitcluster-downstream1 -o name); do if $(kubectl exec -it $tmp_pod -- rabbitmqctl list_vhosts_available_for_standby_replication_recovery | grep -q test); then export downstream_replication_pod=$tmp_pod; fi; done; echo $downstream_replication_pod
```

Next, we will check that there are vhosts available to recover in the downstream cluster:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmqctl list_vhosts_available_for_standby_replication_recovery
```

We will also verify that metrics are successfully generated by the upstream:
```execute
kubectl exec -it rabbitcluster-upstream1-server-0 -- rabbitmq-diagnostics inspect_standby_upstream_metrics
```

Next, we will publish messages to the upstream queue and confirm that queue replication is working 
by ensuring that they are captured by replication log on the downstream queue. For this, we will use RabbitMQ's throughput testing tool, **PerfTest**.

Launch the PerfTest shell:
```execute
kubectl exec deploy/perftest -it -- sh
```

Using PerfTest, publish 10000 messages to the quorum queue created in the upstream cluster:
```execute
bin/runjava com.rabbitmq.perf.PerfTest --uri amqp://test-user:test-password@rabbitcluster-upstream1/test --producers 10 --consumers 0 --predeclared --routing-key "demo.odd.queue" --pmessages 10000 --queue "demo.odd.queue"
```

Exit the shell:
```execute
exit
```

Navigate to the Grafana website, select the **RabbitMQ-Overview** dashboard and confirm that the messages were indeed successfully published (select **rabbitcluster-upstream1** from the cluster dropdown):
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

<font color="red">Note: Use the credentials below to login to the Grafana dashboard:</font>
```execute
printf "Username: admin\nPassword: $(kubectl get secret grafana-admin --namespace monitoring-tools -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)\n"
```

Similarly, select **rabbitcluster-downstream1** from the cluster dropdown above. Notice that it is entirely empty.


Ensure that replicated data is present on the downstream side:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmq-diagnostics inspect_standby_downstream_metrics
```

Simiarly, inspect the replication data associated with the metrics:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmqctl display_disk_space_used_by_standby_replication_data
```

Now, we can proceed with promoting the downstream cluster. First, **delete the upstream cluster**:
```execute
kubectl delete rabbitmqcluster rabbitcluster-upstream1
```

Then, promote the downstream cluster by starting the recovery process:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmqctl promote_standby_replication_downstream_cluster --all-available
```

Create a summary of the recovery process status:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmqctl display_standby_promotion_summary
```

The last timestamp will be used as a starting point for future recovery jobs, so that recovery can be safely launched without replicating 
previously copied data. Notice that restarting the recovery process is an idempotent task:
```execute
kubectl exec -it $downstream_replication_pod -- rabbitmqctl promote_standby_replication_downstream_cluster --all-available
```

Observe the replicated data in the Grafana dashboard:
```dashboard:open-url
url: {{ ingress_protocol }}://grafana.{{ ingress_domain }}
```

Sometimes, the ideal use case is to leverage RabbitMQ transparently as the messaging transport layer, without having to be aware of its inner workings or semantics. For that, we can leverage  **Spring Cloud Data Flow**.