
### Overview

Using the previously created data resources, we will be able to set up a data pipeline using **VMware Spring Cloud Data Flow**.

Let's view the Spring Cloud Data Flow dashboard:
```dashboard:create-dashboard
name: SCDF
url: {{ ingress_protocol }}://scdf.{{ DATA_E2E_BASE_URL }}/dashboard
```

#### Steeltoe

To see SCDF integrated with Steeltoe Streams, register the applications shown below:

<table class="table table-bordered table-striped table-condensed">
<thead>
<tr>
<th>App Name</th>
<th>App Type</th>
<th>App URI</th>
</tr>
</thead>
<tbody>

<tr>
<td><code>steeltoedemoprocessor</code></td>
<td>Processor</td>
<td>docker://projects.registry.vmware.com/steeltoe/basicstreamprocessor:1.25</td>
</tr>

<tr>
<td><code>steeltoedemosink</code></td>
<td>Sink</td>
<td>docker://projects.registry.vmware.com/steeltoe/basicstreamsink:1.23</td>
</tr>

</tbody>
</table>