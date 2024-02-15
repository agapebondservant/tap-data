### Rapid-fire Realtime ML Demo

Launch the Workloads screen:
```dashboard:open-url
{{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/supply-chain
```

Click on **realtimedemo-tap**, scroll to the *Delivery** tile and click on the **URL** that shows up towards the bottom.
(The URL should appear as:)
```dashboard:open-url
https://realtimedemo-tap.default.{{ DATA_E2E_BASE_URL }}
```

Next, show the accelerators - Evidently, Argo Workflows, Sample Realtime analytics demo, etc:
```dashboard:open-url
{{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/supply-chain
```

Enter **kapp**, then click "Choose" on the accelerator entitled **Sample Argo Workflow with KappController**.
This Accelerator includes a link to a Manual with more information. Highlight the copy the link to view.

Now, fill out the fields as appropriate, click "Generate" to generate the template, then click "Explore" to view the generated files.
Observe that the entries made are reflected in the generated template.
**Tanzu** Accelerators allows us to reuse the template as a bootstrap for our own projects: you can download the files, or copy the template as you prefer.

Next, we will deploy a realtime Argo Workflows pipeline by pushing an accelerator template to Github:
```dashboard:open-url
rm -rf data-e2e-demo-app; git clone https://github.com/agapebondservant/data-e2e-demo-app.git; cd data-e2e-demo-app; kapp deploy -a random-forest-training-main --logs -y  -nargo -f demo-ml/appcr/pipeline_app.yaml;
```

Next, we will view the associated pipelines from the ML Panel:
```dashboard:open-url
{{ ingress_protocol }}://tap-gui.{{ DATA_E2E_BASE_URL }}/mlworkflows/mlworkflows-pipelines
```

First, view the Argo Workflows pipelines that was just launched by clicking on **CONSOLE** on the Argo Workflows tile.
(NOTE: It should launch the following window:)
```dashboard:open-url
url: https://argo-workflows.{{ ingress_domain }}
```

Next, view the Data Ingestion pipeline by clicking on **CONSOLE** on the **Spring Cloud Data Flow** tile, and navigate to the **Streams** tab.
(NOTE: It should launch the following window:)
```dashboard:open-url
url: https://scdf.{{ ingress_domain }}
```
The Data Ingestion pipeline loads ML snapshot generated by the ML pipeline from Greenplum into Gemfire regions.

Next, view the ML Model registry pipeline by navigating to **Models** and clicking on **CONSOLE** on the **MlFlow** tile.
Then click on the Models tabs to view the models.
(NOTE: It should launch the following window:)
```dashboard:open-url
url: http://mlflow.{{ ingress_domain }}
```
Select any of the models shown and promote to production, then navigate to the app - the selected model should be displayed on top:
```dashboard:open-url
https://realtimedemo-tap.default.{{ DATA_E2E_BASE_URL }}
```

Next, view the Evidently dashboard by navigating to **Models** and clicking on **CONSOLE** on the **Evidently** tile.
(NOTE: It should launch the following window:)
```dashboard:open-url
url: http://evidently-dashboard.{{ ingress_domain }}
```