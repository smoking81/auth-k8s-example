variable "kubeconfig" {
  description = "The location of kubeconfig where your admin credentials are stored"
  default     = "~/Documents/medium/add-user-k8s/config-admin"
}

variable "username" {
  default = "lancelot"
}

variable "usergroup" {
  default = "knights"
}

locals {
  user-key-file  = "output/user-pki/${var.username}.key"
  user-cert-file = "output/user-pki/${var.username}.crt"
}