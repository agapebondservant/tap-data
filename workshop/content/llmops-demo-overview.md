### Rapid-fire LLMOps Demo
Here is an overview of the LLM pipeline architecture used in this exercise:
![Sample LLMOps Workflow](images/sample-llm-workflow.jpg)

#### Launch app from TAP GUI
View the app in TAP GUI. First, navigate to the Workloads screen:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/supply-chain
```

Launch the app from within the Portal. To do this, click on the **llm-demo** hyperlink, 
use your mouse to click on the pipeline graphic that represents the Supply Chain, 
and use the Arrow key to navigate to the **Delivery** stage at the end of the Chain. 
Then click on the URL that is displayed for the **Delivery** stage.

**NOTE**: Another way to launch the app is by using the **tanzu** cli:
```execute
tanzu apps workload get llm-demo --namespace default
```

On the **AI Bot** tab, enter a question and observe the response.

The question and its corresponding response represent a **prompt-completion pair**.
The prompt-completion will also be tracked in **MLflow**:
```dashboard:open-url
url: {{ ingress_protocol }}://mlflow.{{ DATA_E2E_BASE_URL }}
```

To view the tracked prompt-completions, 
select the **llm-inference-tracking** experiment (on the left) and click on the **Evaluation** column on the right.

You can also view the **json** file that stores tracked completions.
Select the top run that displays under the **Run Name** column, 
click on the **Artifacts** tab,
and then click on **prompt_tracking.json** to view.
Later, the data captured can be used to enhance a training dataset that would use human feedback for finetuning the base LLM,
called **Reinforcement Learning with Human Feedback (RLHF)**.


#### Launch Pipeline
View Argo Workflows in the TAP GUI - the Argo Workflows app should be visible:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/supply-chain
```

Launch Argo Workflows:
```execute
tanzu apps workload get argoworkflows-tap --namespace default
```

Let's deploy an LLM pipeline that will deploy the **base-llm** model that will be consumed by our app. 
Navigate to the Backstage ML home page:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/mlworkflows
```

Click on the tile that reads **Generate an ML pipeline from samples**. 
A filtered list of **accelerators** should display. These are templates that can be used for building ML **pipelines**.

Next, click "Choose" on the accelerator entitled **Sample LLM Argo Workflow with KappController**.
This **Tanzu** Accelerator includes a link to a Manual with more information. Highlight the link to view.

Now, fill out the fields in the Accelerator, click "Generate" to generate the template, then click "Explore" to view the generated files.
Observe that the entries made are reflected in the generated template.
**Tanzu** Accelerators allows us to reuse the template as a bootstrap for our own projects: you can download the files, or copy the template as you prefer.

Let's also view an accelerator that could be used to generate a template for a multi-step training pipeline and webapp frontend.
Go back to the **Backstage ML** home page:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/mlworkflows
```

Click on the tile that reads **Build an ML app from samples**.
A filtered list of **accelerators** should display - this time it shows templates that can be used for building ML **apps**.
Click "Choose" on the accelerator entitled **Sample LLM App Accelerator with multi-step MLflow Workflows**.
This Accelerator also includes a link to a Manual with more information - highlight and copy to view.

Next, we will load a template from Github that has already been previously generated and customized with the previous two accelerators. Fetch the code:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}};
export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && rm -rf ~/sample-llm-app;
git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-llm-app.git -b main-{{session_namespace}} ~/sample-llm-app;
```

Let's view the manifest that was used to enable **GitOps**-ready deployment by viewing our App CR:
```editor:open-file
file: ~/other/resources/appcr/pipeline_app_llm.yaml
```

Once deployed, **TAP** will take care of monitoring the App's resources and tracking when there are changes to the git repo source.
(**TAP** does this by leveraging **kapp-controller**, which is another built-in that comes with **TAP**.) 
In turn, the git repository will store the data scientist's updates 
to the model's **code** and **config**. In many cases, this will not be a one-time activity,
but a continuous, ongoing endeavor. 
For this particular pipeline, changes to **config** can be made via the **MLproject** file. 
It's the <a href="https://mlflow.org/docs/latest/projects.html" target="_blank">MLflow project configuration file</a>, which the data scientist
can use to update different pipeline parameters:
```editor:open-file
file: ~/sample-llm-app/MLproject
```

Each entrypoint invokes a Python command that ultimately runs the user's ML code. 
For instance, see the **promote_model_to_staging** entrypoint command which invokes the promotion step in the pipeline:
```editor:open-file
file: ~/sample-llm-app/MLproject
line: 13
text: "python promote_model_to_staging.py"
before: 0
after: 1
```

The **promote_model_to_staging** entrypoint runs the **promote_model_to_staging.py** script, which in turn calls the actual promotion code.
Observe that this step will publish the model to HuggingFace, 
promote the model to Staging in the Model Registry, and
publish metadata to the data catalog.
```editor:open-file
file: ~/sample-llm-app/promote_model_to_staging.py
```

Also see the **train_model** entrypoint which invokes the pipeline's training step:
```editor:open-file
file: ~/sample-llm-app/MLproject
line: 7
text: "python train_model.py"
before: 0
after: 0
```

The **train_model** entrypoint runs the **train_model.py** script.
Notice that it is currently an empty placeholder:
```editor:open-file
file: ~/sample-llm-app/train_model.py
```

The code in **train_model.py** can be updated to allow **finetuning** or **retraining** of the base LLM model.
We will update the code later.

Now, let's go ahead and deploy the **AppCR** with the current version of our git repo:
```execute
cp ~/other/resources/appcr/pipeline_app_llm.yaml ~/sample-llm-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_llm.yaml ~/sample-llm-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline-llm.yaml ~/sample-llm-app/pipeline.yaml && cp ~/other/resources/appcr/job_llm.yaml ~/sample-llm-app/job.yaml;
cd ~/sample-llm-app; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git add .; git commit -m 'New commit'; git push origin main-{{session_namespace}}; cd -; ytt -f ~/sample-llm-app/pipeline_app.yaml -f ~/sample-llm-app/values.yaml | kapp deploy -a llm-finetuning-pipeline-{{session_namespace}} -f - --logs -y  -n{{session_namespace}}
```

Navigate to Argo Workflows to view the newly deployed workflow:
```dashboard:open-url
url: https://argo-workflows.{{ DATA_E2E_BASE_URL }}
```

In the **Namespace** field, enter the namespace below:
```copy
{{session_namespace}}
```

Our newly deployed workflow should now be visible.

The newly created experiment should also be visible in MlFlow:
```dashboard:open-url
url: http://mlflow.{{ DATA_E2E_BASE_URL }}
```

Now, let's make an update to our ML code.
Update the parameters in the **promote_model_to_staging** step:
```execute
cp ~/sample-llm-app/MLproject.BERT ~/sample-llm-app/MLproject
```

For the next pipeline run, this sets the **pretrained-model-name** to **distilbert-base-cased-distilled-squad**,
**model-description** to **Fine-tuned DistilBERT model**,
and **pipeline-name** to **question-answering**.

Commit to Git:
```execute
cp ~/other/resources/appcr/pipeline_app_llm.yaml ~/sample-llm-app/pipeline_app.yaml && cp ~/other/resources/appcr/values_llm.yaml ~/sample-llm-app/values.yaml && cp ~/other/resources/argo-workflows/pipeline_llm.yaml ~/sample-llm-app/pipeline.yaml && cp ~/other/resources/appcr/job_llm.yaml ~/sample-llm-app/job.yaml;
cd ~/sample-llm-app; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git add .; git commit -m 'New commit'; git push origin main-{{session_namespace}}; cd -;
```

In a few moments, a new ML pipeline which represents our latest changes should pop up.
Watch out for it in the Argo Workflows dashboard:
```dashboard:open-url
url: https://argo-workflows.{{ DATA_E2E_BASE_URL }}
```

#### View model artifacts
Navigate to the MlFlow Model Registry:
```dashboard:open-url
url: {{ ingress_protocol }}://mlflow.{{ DATA_E2E_BASE_URL }}/#/models
```

The LLM app is currently configured to reference a specific version of the model. 
In this case, it looks for the model named **base-llm** with alias **champion**.
Select the aliased model version by clicking the link under the **Latest Version** column.
Next, click on the **Source Run** in the window that displays (should show **promote_model_to_staging**).
An overview of the selected LLM should be shown.
To view the HuggingFace artifacts associated with the model, click on the **Artifacts** tab.


View the LLM in the HuggingFace repository:
```dashboard:open-url
url: https://huggingface.co/tanzuhuggingface/question-answering-finetuned
```

You can also view metadata about the LLM that was tracked in the data catalog (login: datahub/Vmware1!):
```dashboard:open-url
url: {{ ingress_protocol }}://datahub-datahub.{{ DATA_E2E_BASE_URL }}
```

Click on the MLModels card (under the **Explore your data** section), and click on each MLModel to view their captured metadata.





