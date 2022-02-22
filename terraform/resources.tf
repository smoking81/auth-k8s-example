resource "tls_private_key" "user-key" {
  algorithm = "RSA"
}

resource "local_file" "user-key" {
  filename = local.user-key-file
  content  = tls_private_key.user-key.private_key_pem
}

resource "tls_cert_request" "csr" {
  key_algorithm   = tls_private_key.user-key.algorithm
  private_key_pem = tls_private_key.user-key.private_key_pem
  subject {
    common_name  = var.username
    organization = var.usergroup
  }
}

resource "kubernetes_certificate_signing_request_v1" "k8s-csr" {
  metadata {
    name = var.username
  }
  spec {
    usages      = ["client auth"]
    request     = tls_cert_request.csr.cert_request_pem
    signer_name = "kubernetes.io/kube-apiserver-client"
  }
}

resource "local_file" "user-cert-file" {
  filename = local.user-cert-file
  content  = kubernetes_certificate_signing_request_v1.k8s-csr.certificate
}