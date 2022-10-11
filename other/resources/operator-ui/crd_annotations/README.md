## CRD annotation

The Custom Resource Definition (CRD) must have
- a label `sql.tanzu.vmware.com/catalog` (any value) AND
- an annotation with the key `sql.tanzu.vmware.com/ui`

The value of the annotation must be a JSON string. The schema is described below.

### Annotation schema:

| Field Name  | Type    | Description                                                                                                                      |
|-------------|---------|----------------------------------------------------------------------------------------------------------------------------------|
| displayName | string  | **Optional**. This is the name show in the Data Service Selection. If empty, the kind is used instead.                           |
| icon        | string  | **Optional**. This value will be used as the src of an HTML image tag. External images are supported as well as `data:` URIs.    |
| form        | `Form`  | **Optional**. This value will be used to determine how the UI will render a form for the CustomResourceDefinition.               |
| table       | `Table` | **Optional**. This value will be used to determine how the UI will render a table with columns for the CustomResourceDefinition. |

### Table schema:

| Field Name | Type             | Description                                                                        |
|------------|------------------|------------------------------------------------------------------------------------|
| columns[]  | list of `Column` | **Required**. This list of columns will used in a table for the list of instances. |

`Column` can be `PrinterColumn`, `DiskUsage`, or `TimeDelta`.

#### `PrinterColumn` Column schema:
| Field Name | Type   | Description                                                                                                                        |
|------------|--------|------------------------------------------------------------------------------------------------------------------------------------|
| name       | string | **Required**. This is used as the title of the column in the table.                                                                |
| kind       | string | **Required**. This must be the value `PrinterColumn`.                                                                              |
| jsonPath   | string | **Required**. This expression can be used to show a specific field on the CustomResourceDefinition object.                         |
| type       | string | **Optional**. This data type will format the data found from the jsonPath expression. Supported values are `string` and `boolean`. |

This column will show any field from the CustomResourceDefinition object using a jsonPath expression.

Example:
  ```json
  {
    "name": "High Availability",
    "kind": "PrinterColumn",
    "jsonPath": "spec.highAvailability.enabled",
    "type": "boolean"
  }
  ```

#### `DiskUsage` Column schema:
| Field Name             | Type   | Description                                                                                                                       |
|------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------|
| name                   | string | **Required**. This is used as the title of the column in the table.                                                               |
| kind                   | string | **Required**. This must be the value `DiskUsage`.                                                                                 |
| dataServicePodSelector | string | **Required**. This selector should target pods associated with the CustomResourceDefinition that have persistent volumes mounted. |
| instanceNamePodLabel   | string | **Required**. This pod label should identify name of the CustomResourceDefinition.                                                |

This column will show the largest disk utilization for any persistent volumes associated with the pods for the CustomResourceDefinition.

Example:
  ```json
  {
    "name": "Disk Utilization",
    "kind": "DiskUsage",
    "dataServicePodSelector": "app.kubernetes.io/name=mysql",
    "instanceNamePodLabel": "app.kubernetes.io/instance"
  }
  ```

#### `TimeDelta` Column schema:
| Field Name         | Type   | Description                                                             |
|--------------------|--------|-------------------------------------------------------------------------|
| name               | string | **Required**. This is used as the title of the column in the table.     |
| kind               | string | **Required**. This must be the value `TimeDelta`.                       |
| startTime.jsonPath | string | **Required**. This json path expression should evaluate to a timestamp. |
| endTime.jsonPath   | string | **Required**. This json path expression should evaluate to a timestamp. |

This column will show time delta between two timestamps in a Kubernetes object.

Example:
  ```json
  {
    "name": "Duration",
    "kind": "TimeDelta",
    "startTime": {
      "jsonPath": "metadata.creationTimestamp"
    },
    "endTime": {
      "jsonPath": "status.timeCompleted"
    }
  }
  ```


### `Form` schema:

| Field Name | Type              | Description                                                       |
|------------|-------------------|-------------------------------------------------------------------|
| sections[] | list of `Section` | **Required**. Each section will be rendered as a accordion panel. |

### `Section` schema:

| Field Name   | Type               | Description                                                             |
|--------------|--------------------|-------------------------------------------------------------------------|
| name         | string             | **Required**. This is the title of the accordion panel.                 |
| properties[] | list of `Property` | **Required**. These properties will be rendered in the accordion panel. |

`Property` can be `Text`, `Boolean`, `Integer`, `Enum`, `Quantity`, `Grid`, `ClusterObjectName`, or `LocalObjectName`.

#### `Text` Property schema:
| Field Name  | Type   | Description                                                                           |
|-------------|--------|---------------------------------------------------------------------------------------|
| kind        | string | **Required**. This must be the value `Text`.                                          |
| jsonPath    | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.databaseName`) |
| displayName | string | **Required**. This is the label shown for the input.                                  |

This property will result in a textbox.

Example:

  ```json
  {
    "kind": "Text",
    "jsonPath": "spec.databaseName",
    "displayName": "DB Name"
  }
  ```

#### `Boolean` Property schema:
| Field Name  | Type   | Description                                                                         |
|-------------|--------|-------------------------------------------------------------------------------------|
| kind        | string | **Required**. This must be the value `Boolean`.                                     |
| jsonPath    | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.tls.enable`) |
| displayName | string | **Required**. This is the label shown for the input.                                |

This property will result in a checkbox.

Example:

  ```json
  {
    "kind": "Boolean",
    "jsonPath": "spec.tls.enable",
    "displayName": "TLS"
  }
  ```

#### `Integer` Property schema:
| Field Name  | Type   | Description                                                                       |
|-------------|--------|-----------------------------------------------------------------------------------|
| kind        | string | **Required**. This must be the value `Integer`.                                   |
| jsonPath    | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.replicas`) |
| displayName | string | **Required**. This is the label shown for the input.                              |

This property will result in a number field for an integer.

Example:

  ```json
  {
    "kind": "Integer",
    "jsonPath": "spec.replicas",
    "displayName": "Replicas"
  }
  ```

#### `Enum` Property schema:
| Field Name  | Type   | Description                                                                          |
|-------------|--------|--------------------------------------------------------------------------------------|
| kind        | string | **Required**. This must be the value `Enum`.                                         |
| jsonPath    | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.serviceType`) |
| displayName | string | **Required**. This is the label shown for the input.                                 |

This property will result in a dropdown of options.

Example:

  ```json
  {
    "kind": "Enum",
    "jsonPath": "spec.serviceType",
    "displayName": "Service Type"
  }
  ```

**Note**: The OpenAPI v3 schema definition for this property must define the list of valid options using the `enum` field.

#### `Quantity` Property schema:
| Field Name        | Type   | Description                                                                                                                                                          |
|-------------------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| kind              | string | **Required**. This must be the value `Quantity`.                                                                                                                     |
| jsonPath          | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.storageSize`)                                                                                 |
| displayName       | string | **Required**. This is the label shown for the input.                                                                                                                 |
| options.magnitude | string | **Optional**. This value is appended to the quantity. Omitting the magnitude implies unitary values. (e.g. a magnitude of `Gi` will result in a quantity of `1.0Gi`) |
| options.unit      | string | **Optional**. This value is displayed in the input but not appended to the quantity. (e.g a unit of `B` combined with a magnitude of `G` will display as `GB`)       |

This property will result in a number field specifically for `resource.Quantity`.

Example:

  ```json
  {
    "kind": "Quantity",
    "jsonPath": "spec.storageSize",
    "displayName": "Storage Size",
    "options": {
      "magnitude": "G",
      "unit": "B"
    }
  }
  ```

#### `Grid` Property schema:
| Field Name               | Type                        | Description                                                                                                                                   |
|--------------------------|-----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| kind                     | string                      | **Required**. This must be the value `Grid`.                                                                                                  |
| layout.columns           | list of strings             | **Required**. These values will be displayed as the title of the columns of the grid.                                                         |
| layout.rows[].name       | string                      | **Required**. These values will be displayed as the title of the rows of the grid.                                                            |
| layout.rows[].properties | list of Quantity Properties | **Required**. These properties will be rendered for each row. The properties should be ordered to match the columns. Display name is ignored. |

This property will result in a grid of number fields specifically for `resource.Quantity`.

Example:

  ```json
  {
    "kind": "Grid",
    "layout": {
      "columns": ["CPU", "Memory"],
      "rows:": [
        {
          "name": "Data",
          "properties": [
            {
              "kind": "Quantity",
              "jsonPath": "spec.data.cpu",
              "options": {
                "unit": "cores"
              }
            },
            {
              "kind": "Quantity",
              "jsonPath": "spec.data.memory",
              "options": {
                "magnitude": "Gi",
                "unit": "B"
              }
            }
          ]
        },
        {
          "name": "Proxy",
          "properties": [
            {
              "kind": "Quantity",
              "jsonPath": "spec.proxy.cpu",
              "options": {
                "unit": "cores"
              }
            },
            {
              "kind": "Quantity",
              "jsonPath": "spec.proxy.memory",
              "options": {
                "magnitude": "Gi",
                "unit": "B"
              }
            }
          ]
        }
  
      ]
    }
  }
  ```
#### `ClusterObjectName` Property schema:

| Field Name            | Type   | Description                                                                                                                                                         |
|-----------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| kind                  | string | **Required**. This must be the value `ClusterObjectName`.                                                                                                           |
| jsonPath              | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.storageClassName`)                                                                           |
| displayName           | string | **Required**. This is the label shown for the input.                                                                                                                |
| options.kind          | string | **Required**. This is the Kubernetes `kind` associated with the API resource.                                                                                       |
| options.apiVersion    | string | **Required**. This is the Kubernetes `apiVersion` (group and version) associated with the API resource.                                                             |
| options.fieldSelector | string | **Optional**. This is the [field selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/) to limit objects by resource fields. |

This property will result in a datalist HTML element. The application will present the names of cluster-scoped objects from the Kubernetes cluster for the specified `kind` and `apiVersion`. Users can type a custom value or choose from a list of names.

Example:

  ```json
  {
    "kind": "ClusterObjectName",
    "jsonPath": "spec.storageClassName",
    "displayName": "Storage Class",
    "options": {
      "kind": "StorageClass",
      "apiVersion": "storage.k8s.io/v1"
    }
  }
  ```

#### `LocalObjectName` Property schema:

| Field Name            | Type   | Description                                                                                                                                                         |
|-----------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| kind                  | string | **Required**. This must be the value `LocalObjectName`.                                                                                                             |
| jsonPath              | string | **Required**. This should be one of the fields in the CRD. (e.g. `spec.storageClassName`)                                                                           |
| displayName           | string | **Required**. This is the label shown for the input.                                                                                                                |
| options.kind          | string | **Required**. This is the Kubernetes `kind` associated with the API resource.                                                                                       |
| options.apiVersion    | string | **Required**. This is the Kubernetes `apiVersion` (group and version) associated with the API resource.                                                             |
| options.fieldSelector | string | **Optional**. This is the [field selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/) to limit objects by resource fields. |

This property will result in a datalist HTML element. The application will present the names of namespace-scoped objects from the Kubernetes cluster for the specified `kind` and `apiVersion`. The objects will be scoped to the namespace specified for the data service instance. Users can type a custom value or choose from a list of names.

Example:

  ```json
  {
    "kind": "LocalObjectName",
    "jsonPath": "spec.imagePullSecret",
    "displayName": "Image Pull Secret",
    "options": {
      "kind": "Secret",
      "apiVersion": "v1",
      "fieldSelector": "type=kubernetes.io/dockerconfigjson"
    }
  }
  ```
