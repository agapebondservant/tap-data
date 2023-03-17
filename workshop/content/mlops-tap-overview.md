### Tanzu Application Platform

**Tanzu Application Platform** is a _multi-cloud_, _open-source_ based, _DevOps_ platform for deploying and managing
the full spectrum of ML workloads - **pipelines**, **models**, **code** and **data** - from end to end.

It provides the ability to support **MLOps** with **_mix-and-match flexibility_**. 
Users can combine multiple different ML frameworks and solutions, 
or extend features from a single ML framework with DevOps-friendly built-ins.

#### MLOps on TAP: A High-Level Overview
![High-Level Overview of MLOps on TAP](images/tanzumlops2.jpg)

In this session, we will demonstrate how **Tanzu Application Platform** enables **MLOps** with a conventional _supervised learning_ use case. 
We will build an image classifier that will be able to identify objects by name.
Our classifier will be trained on a limited number of *labels* from the well-known **CIFAR 10** dataset.
For the purposes of this exercise, we will build our model from scratch using the popular **Tensorflow (Keras)** framework.
We will demonstrate **transfer learning** (using a *pre-trained model*) in a future exercise.

#### Training a Convolutional Neural Network on TAP
![Training a Convolutional Neural Network on TAP](images/mlops-usecase-overview.jpg)

<div style="text-align: left; justify-content: left; align-items: center; width: 80%; margin-bottom: 20px; font-size: small">
    <img style="float: left; width: 20%; max-width: 20%; margin: 0 10px 0 0" src="images/tip.png"> 
    The following legend will be used throughout the workshop: <br/>
    <img style="float: left; width: 10%; max-width: 10%; margin: 0 10px 0 0" src="images/datasci-tip.png">
    Data Science Tip <br/>
    <img style="float: left; width: 10%; max-width: 10%; margin: 0 10px 0 0" src="images/dataeng-tip.png">
    Data Engineering Tip <br/>
    <img style="float: left; width: 10%; max-width: 10%; margin: 0 10px 0 0" src="images/mlops-tip.png">
    MLOps Tip <br/>
</div>
<div style="clear: left;"></div>

Let's begin!


