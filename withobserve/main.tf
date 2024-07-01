########################################################################################################################
# Determnine if the user named resource group and COS instance exists
########################################################################################################################
data "external" "resource_data" {
  program    = ["bash", "${path.module}/scripts/check-resources.sh"]
  query      = {
    rg_name  = var.resource-group == null ? "does not exist" : var.resource-group
    cos_name = var.cos-instance == null ? "does not exist" : var.cos-instance
    log_name = var.logging-instance == null ? "does not exist" : var.logging-instance
    mon_name = var.monitoring-instance == null ? "does not exist" :var.monitoring-instance
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

#############################################################################
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
# Create observability instances
##############################################################################
module "observability_instances" {
  source = "terraform-ibm-modules/observability-instances/ibm"

  providers = {
    logdna.at = logdna.at
    logdna.ld = logdna.ld
  }
  region                            = var.region
  log_analysis_instance_name        = var.logging-instance == null ? "tryit-log-analysis" : var.logging-instance
  cloud_monitoring_instance_name    = var.monitoring-instance == null ? "tryit-cloud-monitoring" : var.monitoring-instance
  resource_group_id                 = local.resource_group
  log_analysis_plan                 = "7-day"
  cloud_monitoring_plan             = "graduated-tier"
  log_analysis_provision            = data.external.resource_data.result.create_log == "true" ? true : false
  cloud_monitoring_provision        = data.external.resource_data.result.create_mon == "true" ? true : false
  activity_tracker_provision        = false
  enable_platform_logs              = false
  enable_platform_metrics           = false
  log_analysis_tags                 = ["createdby:TRYIT-DA"]
  cloud_monitoring_tags             = ["createdby:TRYIT-DA"]
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

##############################################################################
# Get data in existing instances if customer provided
##############################################################################
data "ibm_resource_instance" "logging" {
  count    = data.external.resource_data.result.create_log == "false" ? 1 : 0
  name     = var.logging-instance
  service  = "logdna"
  location = var.region
}

data "ibm_resource_instance" "monitoring" {
  count    = data.external.resource_data.result.create_mon == "false" ? 1 : 0
  name     = var.monitoring-instance
  service  = "sysdig-monitor"
  location = var.region
}

##############################################################################
# Create a access manager key if customer provided an instance
##############################################################################
resource "ibm_resource_key" "loggingKey" {
  count                = data.external.resource_data.result.create_log == "false" ? 1 : 0
  name                 = "TryitLoggingKey"
  resource_instance_id = data.ibm_resource_instance.logging[0].id
  role                 = "Manager"
}
resource "ibm_resource_key" "monitoringKey" {
  count                = data.external.resource_data.result.create_mon == "false" ? 1 : 0
  name                 = "TryitMonitoringKey"
  resource_instance_id = data.ibm_resource_instance.monitoring[0].id
  role                 = "Manager"
}

##############################################################################
# Connect the logging and monitoring instances to the cluster
##############################################################################
resource "ibm_ob_logging" "logging" {
  depends_on  = [module.ocp_base]
  cluster     = module.ocp_base.cluster_id
  instance_id = data.external.resource_data.result.create_log == "true" ? module.observability_instances.log_analysis_guid : var.logging-instance
}

resource "ibm_ob_monitoring" "monitoring" {
  depends_on  = [module.ocp_base]
  cluster     = module.ocp_base.cluster_id
  instance_id = data.external.resource_data.result.create_mon == "true" ? module.observability_instances.cloud_monitoring_guid : var.monitoring-instance
}
