### Building ML Model

Our Jupyter notebook scripts have been converted into production-ready code hosted in a **Github repo**.
The code template has been registered as an **App Accelerator** in the TAP GUI.
Navigate to the TAP GUI screen below to view the "Sample Tensorflow" accelerator:

```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```

The code template provides a baseline for developing a Convolutional Neural Network with **Tensorflow**, 
one of the most popular deep learning frameworks.

![MLOps - Experimentation](images/mlops-model.jpg)

We will use this to build and train a multiclass CNN model,
which we will tune along the way by tracking and evaluating various classification **performance metrics**. 
At a high level, our workflow will involve:

* **_Ingesting_** the **CIFAR 10** image dataset, including its associated labels as a source of ground truth;
* **_Pre-processing_** the images by transforming them into _n-dimensional tensors_, downscaling and normalizing as necessary;
* Performing a **_train-test-validation_** split;
* **_Training_** a baseline model using the training subset and a configurable set of hyperparameters 
(loss function, optimization function, number of epochs, number of layers, activation function, etc) 
which we will tune in multiple experimental runs;
* **_Validating_** the model using the validation subset;
* **_Evaluating_** and **_tracking_** the model's performance;
* **_Promoting_** the best fit model as a candidate for **Production**.

Let's fetch the code:
```execute
clear; export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}} && export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-ml-app.git ~/sample-ml-app
```

View the code:
```editor:open-file
file: ~/sample-ml-app/app/analytics/cifar_cnn.py
```

This is a refactored version of the experimental code from our **Jupyter Notebook**.
However, refactoring the code was the first step. In order to inject our code into an automated pipeline,
we need to package it in a **standardized**, **reusable** way. The package should run in any environment, 
and it should include everything the environment needs to know in order to run it. To achieve this, we will use 2 things:

1. **MLprojects** 
**MLprojects** are self-contained **MLflow** projects which allow machine learning models to be packaged in a declarative, reusable, portable way.
Here is our MLproject:
```editor:open-file
file: ~/sample-ml-app/MLproject
```

(<font color="red">NOTE:</font> You can learn more about MLprojects here: <a href="https://mlflow.org/docs/latest/projects.html" target="_blank">MLprojects</a>)

2. **Containers**
**Containerizing** our workflow is necessary in order to take advantage of a modern container runtime.
Containerization is a DevOps industry best practice due to its portability, consistency, low resource overhead and auto-scalability.

Let's fetch our containerization code:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}} && export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/mlcode-runner.git ~/mlcode-runner
```

Let's view the code:
```editor:select-matching-text
file: ~/mlcode-runner/app/main.py
text: "submitted_run ="
after: 4
```

(<font color="red">NOTE:</font> The highlighted section is the code that will run our MLproject.)

Next, we will use a **TAP** package called **Build Service** to auto-generate a container image from our code by configuring an **Image Resource**.
**Image Resources** know how to transform source code into images by using both declarative and imperative container building tools.
In our case, it will use **Cloud Native Buildpacks** to auto-detect the type of app, which in turn allows it to bundle in all the right
runtime and build dependencies for the app. It will also serve as a GitOps tool for tracking changes to our code. 
Any time we **git push** to the repository, it will trigger a new container build.

Let's deploy our **Image Resource**. First, we deploy the secret with credentials for our **source** - the git repository:
```execute
clear; GIT_PASSWORD={{DATA_E2E_GIT_TOKEN}} ~/other/resources/bin/kp secret create tbs-demo-git-secret --git-url https://github.com --git-user {{DATA_E2E_GIT_USER}}
```

Next, we deploy the secret with credentials for our **target** - the container registry:
```execute
DOCKER_PASSWORD={{DATA_E2E_REGISTRY_PASSWORD}} ~/other/resources/bin/kp secret create tbs-demo-docker-secret --dockerhub {{DATA_E2E_REGISTRY_USERNAME}}
```

Finally, we deploy our resource:
```execute
~/other/resources/bin/kp image create imgprocessor --tag {{DATA_E2E_REGISTRY_USERNAME}}/ml-image-processor-{{session_namespace}}  \
        --namespace {{session_namespace}} \
        --env MLFLOW_TRACKING_URI=http://mlflow-{{session_namespace}}.{{ ingress_domain }} \
        --env MLFLOW_S3_ENDPOINT_URL=http://minio-{{session_namespace}}.{{ ingress_domain }} \
        --git=https://github.com/{{DATA_E2E_GIT_USER}}/mlcode-runner.git \
        --git-revision=main-{{session_namespace}}
```
Notice that we reference the git repository we fetched earlier,
and we also include some **environment variables** that will be needed to run our **MLproject**.
The new Image builder should show up as a pod in the lower console.











