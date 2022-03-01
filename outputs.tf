output "default_rwx_storage_class" {
  description = "Default read-write-many storage class"
  value       = "portworx-rwx-gp2-sc"
  depends_on  = [ibm_resource_instance.portworx]
}