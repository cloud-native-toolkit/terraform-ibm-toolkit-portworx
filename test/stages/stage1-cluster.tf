module "cluster" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-ocp-vpc.git"

  resource_group_name = var.resource_group_name
  region              = var.region
  ibmcloud_api_key    = var.ibmcloud_api_key
  name                = var.cluster_name
  worker_count        = var.workers
  name_prefix         = var.name_prefix
  exists              = true
  cos_id              = ""
  vpc_subnet_count    = var.subnets
  vpc_name            = ""
  vpc_subnets         = []
}


resource null_resource print_resources {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'Resource group: ${var.resource_group_name}'"
  }
  provisioner "local-exec" {
    command = "echo 'Total Workers: ${module.cluster.total_worker_count}'"
  }
  provisioner "local-exec" {
    command = "echo 'Workers: ${jsonencode(module.cluster.workers)}'"
  }
}