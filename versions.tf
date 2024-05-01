terraform {

  required_version = ">= 1.2.2"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
    selectel = {
      source  = "selectel/selectel"
      version = "~> 3.8.4"
    }
  }
}
