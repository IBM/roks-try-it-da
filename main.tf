########################################################################################################################
# Determnine if the user named resource group and COS instance exists
########################################################################################################################
data "external" "resource_data" {
  program    = ["bash", "${path.module}/scripts/check-resources.sh"]
  query      = {
    rg_name  = var.resource-group == null ? "does not exist" : var.resource-group
    cos_name = var.cos-instance == null ? "does not exist" : var.cos-instance
  }
}

########################################################################################################################
# Resource Group
########################################################################################################################

resource "ibm_resource_group" "res_group" {
  count = data.external.resource_data.result.create_rg == "true" ? 1 : 0
  name  = var.resource-group == null ? "tryit-resource-group" : var.resource-group
}

data "ibm_resource_group" "resource_group" {
  count = data.external.resource_data.result.create_rg == "false" ? 1 : 0
  name  = var.resource-group
}

##############################################################################
# Fetch the COS info if one already exists
##############################################################################
data "ibm_resource_instance" "cos_instance" {
  count             = data.external.resource_data.result.create_cos == "false" ? 1 : 0
  name              = var.cos-instance
  service           = "cloud-object-storage"
}

########################################################################################################################
# VPC + Subnet + Public Gateway
#
# NOTE: This is a very simple VPC with single subnet in a single zone with a public gateway enabled, that will allow
# all traffic ingress/egress by default.
# For production use cases this would need to be enhanced by adding more subnets and zones for resiliency, and
# ACLs/Security Groups for network security.
########################################################################################################################

resource "ibm_is_vpc" "vpc" {
  name                      = "tryit-vpc"
  resource_group            = local.resource_group
  address_prefix_management = "auto"
}

resource "ibm_is_public_gateway" "gateway" {
  name           = "tryit-gateway-1"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group
  zone           = "${var.region}-1"
}

resource "ibm_is_subnet" "subnet_zone_1" {
  name                     = "tryit-subnet-1"
  vpc                      = ibm_is_vpc.vpc.id
  resource_group           = local.resource_group
  zone                     = "${var.region}-1"
  total_ipv4_address_count = 256
  public_gateway           = ibm_is_public_gateway.gateway.id
}


locals {

  resource_group = data.external.resource_data.result.create_rg == "true" ? ibm_resource_group.res_group[0].id : data.ibm_resource_group.resource_group[0].id

  cluster_vpc_subnets = {
    default = [
      {
        id         = ibm_is_subnet.subnet_zone_1.id
        cidr_block = ibm_is_subnet.subnet_zone_1.ipv4_cidr_block
        zone       = ibm_is_subnet.subnet_zone_1.zone
      }
    ]
  }

  worker_pools = [
    {
      subnet_prefix    = "default"
      pool_name        = "default" # ibm_container_vpc_cluster automatically names default pool "default" (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2849)
      machine_type     = var.machine-type
      workers_per_zone = var.number-worker-nodes
    }
  ]
}

##############################################################################
# Create the cluster
##############################################################################
module "ocp_base" {
  source                              = "terraform-ibm-modules/base-ocp-vpc/ibm"
  resource_group_id                   = local.resource_group
  region                              = var.region
  tags                                = ["createdby:TRYIT-DA"]
  cluster_name                        = var.cluster-name
  force_delete_storage                = true
  vpc_id                              = ibm_is_vpc.vpc.id
  vpc_subnets                         = local.cluster_vpc_subnets
  ocp_version                         = var.ocp-version
  worker_pools                        = local.worker_pools
  ocp_entitlement                     = null
  disable_outbound_traffic_protection = true
  #operating_system                    = var.ocp-version == "4.15" ? "RHCOS" : null
  use_existing_cos                    = data.external.resource_data.result.create_cos == "false" ? true : false
  existing_cos_id                     = data.external.resource_data.result.create_cos == "false" ? data.ibm_resource_instance.cos_instance[0].id : null
  cos_name                            = var.cos-instance == null ? "tryit-cos-instance" : var.cos-instance
}
