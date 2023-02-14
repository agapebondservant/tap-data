### Building ML Model Workflow

Building, training and deploying ML models requires several pre-conditions in order to be successful:
* The ability to **deploy** ML models in a **repeatable**, **portable** and **agile** manner;
* The ability to **track** changes to models, including their associated artifacts, metrics, parameters/hyperparameters, etc;
* The ability to track and evaluate model **performance**;
* The ability to store models in a collaborative **registry**;
* The ability to **serve** models via well-documented APIs; etc.

There are several **MLOps** open-source tools which can provide these features:
![MLOps - Different Frameworks](images/different-mlops-frameworks.jpg)

The problem is that different tools often provide different features (at differing levels of maturity/suitability for our use case). 
And sometimes, we would like **mix-and-match flexibility** so that we can easily combine desired features from different tools 
without always having to lock-in to a single vendor. This flexibility is one of the main value propositions of **TAP**, and 
we will be taking advantage of it here.

For the core machine learning workflow, we will use **MLFlow**. **MLFlow** is a lightweight, cloud-native MLOps solution
which provides the ability to mix-and-match with other frameworks where necessary. 
![MLOps - Experimentation](images/mlops-model.jpg)

(With **MLFlow**, an additional **orchestration layer** is required to deploy our machine learning code as 
an **ML pipeline**, with loosely coupled, scalable, resilient, portable steps.
We will set up the orchestration later in the workshop.)

Let's begin!

#### How to deploy

Now we're ready to start building our model for production. 
We will refactor the code that we generated with our **Jupyter Notebooks** during our initial experiments.

View the Jupyter Notebook by clicking on the Jupyter tab and selecting the "Image Processing" notebook. 
We can export the code by selecting "File -> Download as Python".
Next, we will begin working with refactored code and modify it so that it can be deployed by a pipeline orchestrator.






