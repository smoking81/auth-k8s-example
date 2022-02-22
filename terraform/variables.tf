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

locals {
  user-key-file  = "output/user-pki/${var.username}.key"
  user-cert-file = "output/user-pki/${var.username}.crt"
}