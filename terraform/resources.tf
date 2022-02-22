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

resource "kubernetes_namespace_v1" "round-table" {
  metadata {
    name = "round-table"
  }
}

resource "kubernetes_cluster_role_v1" "pod-reader-cr" {
  metadata {
    name = "pod-reader"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_v1" "node-reader-cr" {
  metadata {
    name = "node-reader"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_v1" "deployment-admin-r" {
  metadata {
    name      = "deployment-admin"
    namespace = kubernetes_namespace_v1.round-table.metadata[0].name
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "node-reader-crb" {
  metadata {
    name = "node-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.node-reader-cr.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = var.username
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role_binding_v1" "pod-reader-rb" {
  metadata {
    name      = "pod-reader"
    namespace = kubernetes_namespace_v1.round-table.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.pod-reader-cr.metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = var.usergroup
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role_binding_v1" "deployment-admin-rb" {
  metadata {
    name      = "deployment-admin"
    namespace = kubernetes_namespace_v1.round-table.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployment-admin-r.metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = var.usergroup
    api_group = "rbac.authorization.k8s.io"
  }
}