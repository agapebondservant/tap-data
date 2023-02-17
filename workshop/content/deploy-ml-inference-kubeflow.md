### Building and Deploying Predictive Apps

![MLOps - Experimentation](images/mlops-inference-kubeflow.jpg)

Now we will deploy the predictive apps that will consume the Tensorflow model we built previously,
and use it to generate image label predictions. With **TAP**, we are able to deploy our ML apps
along with our models using the same GitOps-ready platform.

Our sample ML code includes a **Streamlit** web app which will accept an uploaded image and return its predicted label for it.
It will also display some of the model's performance metrics which were evaluated during training, as a point of reference.

Let's take a quick look at the main module which will drive the app:
```editor:open-file
file: ~/sample-ml-app/app/analytics/home.py
```

Next, we need the GitOps code that will handle the deployment and lifecycle management of the app.
Again, this is made easy with **TAP**.
For our web app, we will use of the resource called **Workloads**,
which make use of out-of-the-box pipelines called **Supply Chains** to manage the app.

Let's see if we can reuse an existing Workload template from our **Accelerator** portal.
Navigate to the **TAP GUI**:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```

Click on the "+" menu icon (left panel), and enter "project" in the search field.
Then, click "Choose", enter "test" in all the required fields, and click "Explore File".
In the pop-up that displays, you should be able to navigate to the _config/workload.yaml_ file.

Here's the manifest that we will use to deploy the app:
```editor:open-file
file: ~/other/resources/tapworkloads/workload.yaml
```

Note that it includes an "openapi" field, which will be used to render an OpenAPI-3 compatible interface.

Now, let's deploy the app:
```execute
tanzu apps workload create image-processor -f ~/other/resources/tapworkloads/workload.yaml --yes -n {{session_namespace}}
```

While our app is deploying, let's see a previously deployed example of what the workflow should look like.

Navigate to a pre-existing deployment of MLflow:
```dashboard:open-url
url: {{ ingress_protocol }}://mlflow.{{ ingress_domain }}
```

Select the **convolutional_neural_network_team_main** experiment (on the left),
and enter **metrics.accuracy_score** in the search field, then select the run in the search results.
Notice the tracked fields in the **Metrics** and **Artifacts** section; these were tracked and stored during the model training phase.

Also, select the **Models** tab. There should be several candidate models shown.
The selected candidate model should show up as **cifar_cnn**. The model can be promoted (or demoted) through the UI, as shown,
or programmatically (during the training).

Navigate to a pre-existing sample app deployment:
```dashboard:dashboard:create-dashboard
name: Demo
url: {{ ingress_protocol }}://image-processor.default.{{ ingress_domain }}
```

Upload a few images to the app and observe the predictions it yields.
Also notice the metrics associated with the model used by the app.

<font color="red">NOTE: If it shows "Training is in progress",
then it means that it could not locate any ML model named **cifar_cnn** that is in the **Production** phase.
Navigate to MLflow above to change the Model Stage from the Models tab.</font>

Last, view the pipeline that was used to build the model:
```dashboard:reload-dashboard
name: Kubeflow
url: {{ ingress_protocol }}://kubeflow-pipelines.{{ ingress_domain }}
```




