##################################################
# Create and attach block storage to worker nodes
##################################################


resource "null_resource" "print_resources" {
  provisioner "local-exec" {
    command = "echo 'Resource group: ${var.resource_group_name}'"
  }
  provisioner "local-exec" {
    command = "echo 'Cluster: ${var.cluster_name}'"
  }
}

module "resource_group" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-resource-group.git"

  resource_group_name = var.resource_group_name
  provision           = false
}

module "cluster" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-ocp-vpc.git?ref=v1.10.2"

  resource_group_name = var.resource_group_name
  region              = var.region
  ibmcloud_api_key    = var.ibmcloud_api_key
  name                = var.cluster_name
  worker_count        = 2
  name_prefix         = var.name_prefix
  exists              = true
  cos_id              = ""
  vpc_subnet_count    = 1
  vpc_name            = ""
  vpc_subnets         = []
}


data "ibm_is_subnet" "subnets" {
  count      = var.worker_count
  identifier = var.workers[count.index].zone
  #todo: zone should be renamed to subnet once cluster module is updated
}

resource "null_resource" "print_volume_names" {
  depends_on = [
    data.ibm_is_subnet.subnets
  ]
  count = var.install_storage ? var.worker_count : 0
  provisioner "local-exec" {
    command = "echo 'Creating volume: ${substr("${replace(var.name_prefix, "_", "-")}${length(var.name_prefix) > 0 ? "-" : ""}pwx-${count.index}-${var.workers[count.index].id}", 0, 61)}'"
  }
}

# Create a block storage volume per worker.
resource "ibm_is_volume" "volume" {
  depends_on = [
    data.ibm_is_subnet.subnets,
    null_resource.print_volume_names
  ]
  count = var.install_storage ? var.worker_count : 0

  capacity       = var.storage_capacity
  iops           = var.storage_profile == "custom" ? var.storage_iops : null
  name           = substr("${replace(var.name_prefix, "_", "-")}${length(var.name_prefix) > 0 ? "-" : ""}pwx-${count.index}-${var.workers[count.index].id}", 0, 61) #max length of 61 characters for volume name
  profile        = var.storage_profile
  resource_group = module.resource_group.id
  zone           = data.ibm_is_subnet.subnets[count.index].zone
  #todo: zone should be renamed to subnet
}



data "ibm_container_vpc_cluster_worker" "workers" {
  count = var.install_storage ? var.worker_count : 0

  cluster_name_id   = module.cluster.id
  resource_group_id = module.resource_group.id
  worker_id         = var.workers[count.index].id
}

locals {
  worker_volume_map = zipmap(data.ibm_container_vpc_cluster_worker.workers.*.id, ibm_is_volume.volume.*.id)
}

# Attach block storage to worker
resource "null_resource" "volume_attachment" {
  count = var.install_storage ? var.worker_count : 0

  depends_on = [
    ibm_is_volume.volume,
    data.ibm_container_vpc_cluster_worker.workers
  ]

  triggers = {
    IBMCLOUD_API_KEY  = base64encode(var.ibmcloud_api_key)
    REGION            = var.region
    RESOURCE_GROUP_ID = module.resource_group.id
    CLUSTER_ID        = module.cluster.id
    WORKER_ID         = length(data.ibm_container_vpc_cluster_worker.workers) > 0 ? data.ibm_container_vpc_cluster_worker.workers[count.index].id : 0
    VOLUME_ID         = length(ibm_is_volume.volume) > 0 ? ibm_is_volume.volume[count.index].id : 0
    BIN_DIR           = module.clis.bin_dir
  }

  provisioner "local-exec" {
    environment = {
      IBMCLOUD_API_KEY  = base64decode(self.triggers.IBMCLOUD_API_KEY)
      REGION            = self.triggers.REGION
      RESOURCE_GROUP_ID = self.triggers.RESOURCE_GROUP_ID
      CLUSTER_ID        = self.triggers.CLUSTER_ID
      WORKER_ID         = self.triggers.WORKER_ID
      VOLUME_ID         = self.triggers.VOLUME_ID
      BIN_DIR           = self.triggers.BIN_DIR
    }

    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/volume_attachment.sh")
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      IBMCLOUD_API_KEY  = base64decode(self.triggers.IBMCLOUD_API_KEY)
      REGION            = self.triggers.REGION
      RESOURCE_GROUP_ID = self.triggers.RESOURCE_GROUP_ID
      CLUSTER_ID        = self.triggers.CLUSTER_ID
      WORKER_ID         = self.triggers.WORKER_ID
      VOLUME_ID         = self.triggers.VOLUME_ID
      BIN_DIR           = self.triggers.BIN_DIR
    }

    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/volume_attachment_destroy.sh")
  }
}

# #############################################
# # Create 'Databases for Etcd' service instance
# #############################################
resource "ibm_database" "etcd" {
  count                        = var.provision && var.create_external_etcd ? 1 : 0
  location                     = var.region
  members_cpu_allocation_count = var.etcd_members_cpu_allocation_count
  members_disk_allocation_mb   = var.etcd_members_disk_allocation_mb
  members_memory_allocation_mb = var.etcd_members_memory_allocation_mb
  name                         = "${var.name_prefix}-pwx-etcd"
  plan                         = var.etcd_plan
  resource_group_id            = module.resource_group.id
  service                      = "databases-for-etcd"
  service_endpoints            = var.etcd_service_endpoints
  version                      = var.etcd_version
  users {
    name     = var.etcd_username
    password = var.etcd_password
  }
}

# # find the object in the connectionstrings list in which the `name` is var.etcd_username
locals {
  etcd_user_connectionstring = (var.create_external_etcd ?
    ibm_database.etcd[0].connectionstrings[index(ibm_database.etcd[0].connectionstrings[*].name, var.etcd_username)] :
  null)
}

resource "null_resource" "portworx_secret" {
  count = var.provision && var.create_external_etcd ? 1 : 0

  depends_on = [
    ibm_database.etcd
  ]

  triggers = {
    config_path      = module.cluster.config_file_path
    etcd_secret_name = var.etcd_secret_name
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = self.triggers.config_path
    }
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl create secret generic ${self.triggers.etcd_secret_name} --from-literal=username='${var.etcd_username}' --from-literal=password='${var.etcd_password}' --from-literal=ca.pem='${base64decode(local.etcd_user_connectionstring.certbase64)}' -n kube-system"
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      KUBECONFIG = self.triggers.config_path
    }

    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl delete secret generic ${self.triggers.etcd_secret_name} -n kube-system --ignore-not-found"
  }
}





# ##################################
# # Install Portworx on the cluster
# ##################################
resource "random_string" "random" {
  length  = 8
  special = false
}

module "clis" {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"
  clis   = ["yq", "jq", "igc", "helm"]
}

resource "ibm_resource_instance" "portworx" {
  depends_on = [
    null_resource.volume_attachment,
    null_resource.portworx_secret,
    module.clis
  ]

  count = var.provision ? 1 : 0

  name              = "${var.name_prefix}-pwx-service-${random_string.random.result}"
  service           = "portworx"
  plan              = "px-enterprise"
  location          = var.region
  resource_group_id = module.resource_group.id

  tags = [
    "clusterid:${module.cluster.id}",
  ]

  parameters = {
    apikey       = var.ibmcloud_api_key
    cluster_name = module.cluster.name
    clusters     = module.cluster.id
    etcd_endpoint = (var.create_external_etcd ?
      "etcd:https://${local.etcd_user_connectionstring.hosts[0].hostname}:${local.etcd_user_connectionstring.hosts[0].port}"
      : null
    )
    etcd_secret      = var.create_external_etcd ? var.etcd_secret_name : null
    internal_kvdb    = var.create_external_etcd ? "external" : "internal"
    portworx_version = "Portworx: 2.6.2.1 , Stork: 2.6.0"
    secret_type      = "k8s"
    config_path      = module.cluster.config_file_path
    bin_dir          = module.clis.bin_dir
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = module.cluster.config_file_path
    }
    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/portworx_wait_until_ready.sh")
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      CLUSTER    = self.parameters.cluster_name
      KUBECONFIG = self.parameters.config_path
      BIN_DIR    = self.parameters.bin_dir
    }

    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/wipe_portworx.sh")
  }
}
