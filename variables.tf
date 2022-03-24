variable "provision" {
    default     = true
    description = "If set to true installs Portworx on the given cluster"
}

variable "ibmcloud_api_key" {
  description = "Get the ibmcloud api key from https://cloud.ibm.com/iam/apikeys"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "The prefix name for the service. If not provided it will default to the resource group name"
  default     = ""
}

variable "region" {
    description = "The region Portworx will be installed in: us-south, us-east, eu-gb, eu-de, jp-tok, au-syd, etc.."

}

variable "resource_group_name" {
    description = "Resource Group in your account. List all available resource groups with: ibmcloud resource groups"
}

variable "storage_capacity"{
    type = number
    default = 200
    description = "Storage capacity in GBs"
}

variable "storage_iops" {
    type = number
    default = 10
    description = "This is used only if a user provides a custom storage_profile"
}

variable "storage_profile" {
    type = string
    default = "10iops-tier"
    description = "The is the storage profile used for creating storage"
}

variable "worker_count" {
    type = number
    description = "Number of worker nodes"
}

variable "workers" {
    type = list
    description = "Number of worker nodes"
}


# etcd variables....

variable "create_external_etcd" {
    type = bool
    default = false
    description = "Do you want to create an external_etcd? `True` or `False`"
}

variable "etcd_members_cpu_allocation_count" {
  default = 9
  type = number
}

variable "etcd_members_disk_allocation_mb" {
  default = 393216
  type = number
}

variable "etcd_members_memory_allocation_mb" {
  default = 24576
  type = number
}

variable "etcd_plan" { 
  default = "standard"
  type = string
} 

variable "etcd_version" {
  default = "3.3"
  type = string
}

variable "etcd_service_endpoints" {
  default = "private"
  type = string
}




# These credentials have been hard-coded because the 'Databases for etcd' service instance is not configured to have a publicly accessible endpoint by default.
# You may override these for additional security.
variable "etcd_username" {
  default = "portworxuser"
  type = string
  description = "etcd_username: You may override for additional security."
}
variable "etcd_password" {
  default = "etcdpassword123"
  type = string
  description = "etcd_password: You may override for additional security."
}
variable "etcd_secret_name" {
  # don't change this
  default = "px-etcd-certs"
  type = string
  description = "etcd_secret_name: This should not be changed unless you know what you're doing."
}

