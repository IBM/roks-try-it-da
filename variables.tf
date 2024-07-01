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
  description = "You have 3 choices. If you leave this blank, a new COS instance will be created for you. If you specify the name of an existing COS instance, it will be used. Or a new instance will be created for the name you provide."
  default     = null
}

variable "resource-group" {
  type        = string
  description = "You have 3 choices. If you leave this blank, a new resource group will be created for you. If you specify the name of an existing resource group, it will be used. Or a new resource group will be created for the name you provide."
  default     = null
}
