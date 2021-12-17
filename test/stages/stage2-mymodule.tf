module "portworx_module" {
  source = "./module"
  resource_group_name = var.resource_group_name
  region              = var.region
  ibmcloud_api_key    = var.ibmcloud_api_key
  cluster_name        = module.cluster.name
  name_prefix         = var.name_prefix
  workers             = module.cluster.workers
  worker_count        = module.cluster.total_worker_count
  create_external_etcd = var.create_external_etcds
}

