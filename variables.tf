variable "ibmcloud_api_key" {
  description = "APIkey that's associated with the account to use"
  type        = string
  sensitive   = true
}

variable "cluster-name" {
  type        = string
  description = "Name of the new IBM Cloud OpenShift Cluster"
}

variable "region" {
  type        = string
  description = "IBM Cloud region. Use 'ibmcloud regions' to get the list"
}

variable "number-worker-nodes" {
  type        = number
  description = "The number of workers to create in the cluster"
  default     = 2
}

variable "ocp-version" {
  type        = string
  description = "Major.minor version of the OCP cluster to provision"
}

variable "machine-type" {
  type        = string
  description = "Worker node machine type. Use 'ibmcloud ks flavors --zone <zone>' to retrieve the list."
  default     = "bx2.4x16"
}

variable "cos-instance" {
  type        = string
  description = "Leave blank to have a new COS instance created. Specify an existing COS instance if you want to reuse it."
  default     = null
}

variable "resource-group" {
  type        = string
  description = "Leave blank to have a new resource group created. Specify an existing resource group if you want to reuse it."
  default     = null
}
