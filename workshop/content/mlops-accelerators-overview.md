### Using Accelerators

One of the major challenges of the **ML Lifecycle** is **lengthy deployment cycles**. 
On average, machine learning models take up to a month (or more) to deploy to production.
There are many reasons for this, making **accelerating** the ML deployment cycle a major objective for many enterprises.

One of the ways that **TAP** can help with this is by speeding up training times (where appropriate) via seamless integration with **GPUs**,
which will be covered in a separate session. Another way is through **Accelerators**. What are **accelerators**, and how do they help?
Simply put, **accelerators** provide a catalog of reusable prototypes and templates that data scientists can use to avoid reinventing 
the wheel for common tasks. **Accelerators** are organization-specific archetypes which are hosted in the group's Git repository, and
they can be anything from reference architectures to model schemas to Jupyter notebooks and reusable data pipelines.
By reusing these archetypes, they are able to cut down on their overall time-to-prod.

Navigate to the **Accelerator** view by clicking the "+" icon below:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```


#### How to deploy

Deploying an accelerator is pretty straightforward. Let's test it out by starting an accelerator for **reference documentation**.

First, let's set up the git repository that will host our accelerator:
```execute
export DATA_E2E_GIT_TOKEN={{DATA_E2E_GIT_TOKEN}} && export DATA_E2E_GIT_USER={{DATA_E2E_GIT_USER}} && git clone https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-accelerator.git ~/sample-accelerator
```

Let's generate the reference doc:
```execute
cat << EOF > ~/sample-accelerator/README.md
## Data Catalog Best Practices
EOF
```

We'll also include the optional **accelerator.yaml** file, so that we can add some custom options to our accelerator.
In this, we will add "practise" as a tag to our accelerator.
```execute
cat << EOF > ~/sample-accelerator/accelerator.yaml
accelerator:
  displayName: Data Catalog Best Practices
  description: Best Practices for Search and Discovery of Data Assets
  iconUrl: https://upload.wikimedia.org/wikipedia/commons/1/1b/ML_Ops_Venn_Diagram.svg
  tags:
  - "practise"
EOF
```

View the files that we just generated:
```editor:open-file
file: ~/sample-accelerator
```

Push the files to GitHub:
```execute
cd ~/sample-accelerator; git config --global user.email 'eduk8s@example.com'; git config --global user.name 'Educates'; git commit -a -m 'New commit'; git push origin main-{{session_namespace}}; cd -
```

Now, go ahead and register the accelerator using the **tanzu cli**:
```execute
tanzu acc create data-catalog-{{session_namespace}} --git-repository https://${DATA_E2E_GIT_USER}:${DATA_E2E_GIT_TOKEN}@github.com/${DATA_E2E_GIT_USER}/sample-accelerator.git --git-branch main-{{session_namespace}}
```

Go to the **Accelerators** page in **TAP** and locate the new accelerator by entering "practise" in the Search Bar:
```dashboard:open-url
url: {{ ingress_protocol }}://tap-gui.{{ ingress_domain }}/create
```






