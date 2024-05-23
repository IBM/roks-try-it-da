terraform {
  required_version = ">= 1.5.0, <1.7.0"
  required_providers {
    # Use a range in modules
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">= 1.59.0"
    }
    logdna = {
      source  = "logdna/logdna"
      version = "1.14.2"
    }
  }
}
