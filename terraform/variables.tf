variable "kubeconfig" {
  description = "The location of kubeconfig where your admin credentials are stored"
}

variable "kubecontext" {
  description = "A context for an admin user"
}

variable "username" {
}

variable "usergroup" {
}

variable "admin" {
}

variable "k8s-certs-path" {
  description = "The folder where your cluster saves the k8s certificates"
}

locals {
  user-key-file  = "output/user-pki/${var.username}.key"
  user-cert-file = "output/user-pki/${var.username}.crt"
  admin-key-file = "output/admin-pki/${var.admin}.key"
  admin-cert-file = "output/admin-pki/${var.admin}.crt"
}