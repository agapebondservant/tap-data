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

Deploying an accelerator is pretty straightforward. 




