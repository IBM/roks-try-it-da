########################################################################################################################
# Resource Group
########################################################################################################################

resource "ibm_resource_group" "res_group" {
  count = var.resource-group == null ? 1 : 0
  name  = "tryit-resource-group"
}

data "ibm_resource_group" "resource_group" {
  count = var.resource-group == null ? 0 : 1
  name  = var.resource-group
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

  resource_group = var.resource-group == null ? ibm_resource_group.res_group[0].id : data.ibm_resource_group.resource_group[0].id

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
# Fetch the COS info if one already exists
##############################################################################
data "ibm_resource_instance" "cos_instance" {
  count             = var.cos-instance == null ? 0 : 1
  name              = var.cos-instance
  service           = "cloud-object-storage"
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
  log_analysis_instance_name        = "tryit-log-analysis"
  cloud_monitoring_instance_name    = "tryit-cloud-monitoring"
  resource_group_id                 = local.resource_group
  log_analysis_plan                 = "7-day"
  cloud_monitoring_plan             = "graduated-tier"
  log_analysis_provision            = var.logging-instance == null ? true : false
  cloud_monitoring_provision        = var.monitoring-instance == null ? true : false
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
  depends_on                          = [ibm_is_vpc.vpc]
  ibmcloud_api_key                    = var.ibmcloud_api_key
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
  use_existing_cos                    = var.cos-instance == null ? false :  true
  existing_cos_id                     = var.cos-instance == null ? null : data.ibm_resource_instance.cos_instance[0].id
  cos_name                            = "tryit-cos-instance"
}

##############################################################################
# Get data in existing instances if customer provided
##############################################################################
data "ibm_resource_instance" "logging" {
  count    = var.logging-instance == null ? 0 : 1
  name     = var.logging-instance
  service  = "logdna"
  location = var.region
}

data "ibm_resource_instance" "monitoring" {
  count    = var.monitoring-instance == null ? 0 : 1
  name     = var.monitoring-instance
  service  = "sysdig-monitor"
  location = var.region
}

##############################################################################
# Create a access manager key if customer provided an instance
##############################################################################
resource "ibm_resource_key" "loggingKey" {
  count                = var.logging-instance == null ? 0 : 1
  name                 = "TryitLoggingKey"
  resource_instance_id = data.ibm_resource_instance.logging[0].id
  role                 = "Manager"
}
resource "ibm_resource_key" "monitoringKey" {
  count                = var.monitoring-instance == null ? 0 : 1
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
  instance_id = var.logging-instance == null ? module.observability_instances.log_analysis_guid : var.logging-instance
}

resource "ibm_ob_monitoring" "monitoring" {
  depends_on  = [module.ocp_base]
  cluster     = module.ocp_base.cluster_id
  instance_id = var.monitoring-instance == null ? module.observability_instances.cloud_monitoring_guid : var.monitoring-instance
}
