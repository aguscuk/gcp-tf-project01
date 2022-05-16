/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


provider "google" {
  project                 = var.project
  region                  = var.region
  credentials             = var.google_credentials
}


/******************************************
	VPC configuration
 *****************************************/
module "vpc" {
  source                                 = "../modules/vpc"
  network_name                           = "${var.env}-${var.network_name}"
  auto_create_subnetworks                = var.auto_create_subnetworks
  routing_mode                           = var.routing_mode
  project_id                             = var.project_id
  description                            = var.description
  shared_vpc_host                        = var.shared_vpc_host
  delete_default_internet_gateway_routes = var.delete_default_internet_gateway_routes
  mtu                                    = var.mtu
}

/******************************************
	Subnet configuration
 *****************************************/
module "subnets" {
  source           = "../modules/subnets"
  project_id       = var.project_id
  network_name     = module.vpc.network_name
  subnets          = var.subnets
  secondary_ranges = var.secondary_ranges
}

/******************************************
	Routes
 *****************************************/
module "routes" {
  source            = "../modules/routes"
  project_id        = var.project_id
  network_name      = module.vpc.network_name
  routes            = var.routes
  module_depends_on = [module.subnets.subnets]
}

/******************************************
	Firewall rules
 *****************************************/
# locals {
#   rules = [
#     for f in var.firewall_rules : {
#       name                    = f.name
#       direction               = f.direction
#       priority                = lookup(f, "priority", null)
#       description             = lookup(f, "description", null)
#       ranges                  = lookup(f, "ranges", null)
#       source_tags             = lookup(f, "source_tags", null)
#       source_service_accounts = lookup(f, "source_service_accounts", null)
#       target_tags             = lookup(f, "target_tags", null)
#       target_service_accounts = lookup(f, "target_service_accounts", null)
#       allow                   = lookup(f, "allow", [])
#       deny                    = lookup(f, "deny", [])
#       log_config              = lookup(f, "log_config", null)
#     }
#   ]
# }

# module "firewall_rules" {
#   source       = "../modules/firewall-rules"
#   project_id   = var.project_id
#   network_name = module.vpc.network_name
#   rules        = local.rules
# }

module "net-firewall" {
  source                  = "../modules/fabric-net-firewall"
  project_id              = var.project_id
  network                 = module.vpc.network_name
  internal_ranges_enabled = true
  internal_ranges         = ["10.0.0.0/8"]
  internal_target_tags    = ["internal"]
  custom_rules = {
    ingress-database = {
      description          = "database mysql ingress rule, tag-based."
      direction            = "INGRESS"
      action               = "allow"
      ranges               = ["192.168.0.0"]
      sources              = ["mysql"]
      targets              = ["mysql", "postgresql"]
      use_service_accounts = false
      rules = [
        {
          protocol = "tcp"
          ports    = ["3306","5432"]
        }
      ]
      extra_attributes = {}
    }
  }
}