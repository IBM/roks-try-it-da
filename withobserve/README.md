# Red Hat OpenShift on IBM Cloud Starters
This repository holds the contents of the ROKS Starters deployable architectures that includes observability
<br/><br/>
The goal of this DA is to provide the ability for new users to quickly create a simply OpenShift cluster in IBM Cloud. The cluster that will be created will be a single zone cluster. It will be created in the "1" zone in the region selected. A new VPC is created with a new default subnet created in the first zone. Attached to that subnet is a public gatway. The cluster is created in this new VPC.
<br/><br/>
You must provide a target region for all of the resources created. You can get the list of regions via the following command:
```
ibmcloud regions
```
You may provide the machine-type of the cluster worker node. If you do not specify a machine type, the cluster will default to `bx2.4x16` worker flavors. If you want to specify your own flavor type, it must exist in the first zone in the region you select. If for example you select the Toronto MZR, you can execute this command to see the list of flavors available in the first zone in the Toronto MZR:
```
ibmcloud ks flavors --provider vpc-gen2 --zone ca-tor-1
```
OpenShift on IBM Cloud uses an IBM Cloud Object Storage bucket as the storage backing for its internal registry. The provisioning process creates a bucket in the provided COS instance. Provide the name of an existing IBM Cloud Object Storage instance that you want to use. If you don't provide an instance name, one will be created for you.
<br/><br/>
You may provide a existing resource group where all of the new resources will be created. If you do not provide one, one will be created for you.

## Created Resources
The following items will get created:
1. A resource group named `tryit-resource-group` (if no existing resource group is provided)
2. A subnet named `tryit-subnet-1` in zone 1 of the chosen region in the resource group
3. A public gateway named `tryit-gateway-1` attached to the subnet in the resource group
4. A vpc named `tryit-vpc` containing the above subnet and public gateway in the resource group
5. A Cloud logging instance called `tryit-log-analysis`
6. A Cloud Monitoring instance called `tryit-cloud-monitoring`
7. A COS instance named `tryit-cos-instance` (if no existing COS instance is provided)
8. A single zone cluster in the created subnet and vpc with the user specified number of workers in the resource group. The cluster is already integrated with logging and monitoring but not with any encryption service or secrets management. It will be publicly accessible.

## Required IAM access policies
You need the following permissions to run this module.

- IAM Services
  - **Kubernetes** service (to create and access a cluster)
      - `Administrator` platform access
      - `Manager` service access
  - **VPC Infrastructure** service (to create VPC resources)
      - `Administrator` platform access
      - `Manager` service access
  - **All Account Management** service (to create a resource group)
      - `Administrator` platform access
      - `Manager` service access
  - **Cloud Object Storage** service (to create a COS instance)
      - `Administrator` platform access
      - `Manager` service access
 - **IBM Log Anaysis** service (to create a Log Analysis instance)
      - `Administrator` platform access
      - `Manager` service access
- **IBM Cloud Monitoring** service (to create a Monitoring instance)
      - `Administrator` platform access
      - `Manager` service access


## Requirements
| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, <1.7.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.59.0 |

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ibmcloud_api_key | APIkey that's associated with the account to use | `string` | none | yes |
| cluster-name | Name of the target or new IBM Cloud OpenShift Cluster | `string` | none | yes |
| region | IBM Cloud region. Use 'ibmcloud regions' to get the list | `string` | us-east | yes |
| ocp-version | Major.minor version of the OCP cluster to provision | `string` | none | yes |
| number-worker-nodes | The number of GPU nodes expected to be found or to create in the cluster | `number` | 2 | yes |
| machine-type | Worker node machine type. Use 'ibmcloud ks flavors --zone <zone>' to retrieve the list.| `string` | bx2.4x16 | yes |
| cos-instance | A pre-existing COS service instance where a bucket will be provisioned to back the internal registry. If you leave this blank, a new COS instance will be created for you | `string` | none | no |
| resource-group | A pre-existing resource group. If you leave this blank, a new resource group will be created for you | `string` | none | no |

## Sample terraform.tfvars file

**NOTE:** If running Terraform yourself, pass in your `ibmcloud_api_key` in the environment variable `TF_VAR_ibmcloud_api_key`

```
cluster-name = "cluster-abc"
region = "ca-tor"
ocp-version = "4.15"
#number-worker-nodes = 2
#machine-type = "bx2.4x16"
#cos-instance = "Cloud Object Storage-abc"
#resource-group = "my-resource-group"
```
