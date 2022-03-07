resource "tls_private_key" "user-key" {
  algorithm = "RSA"
}

resource "tls_private_key" "admin-key" {
  algorithm = "RSA"
}

resource "local_file" "user-key" {
  filename = local.user-key-file
  content  = tls_private_key.user-key.private_key_pem
}

resource "local_file" "admin-key" {
  filename = local.admin-key-file
  content  = tls_private_key.admin-key.private_key_pem
}

resource "tls_cert_request" "user-csr" {
  key_algorithm   = tls_private_key.user-key.algorithm
  private_key_pem = tls_private_key.user-key.private_key_pem
  subject {
    common_name  = var.username
    organization = var.usergroup
  }
}

resource "tls_cert_request" "admin-csr" {
  key_algorithm   = tls_private_key.admin-key.algorithm
  private_key_pem = tls_private_key.admin-key.private_key_pem
  subject {
    common_name  = var.admin
    organization = "system:masters"
  }
}

resource "kubernetes_certificate_signing_request_v1" "k8s-csr" {
  metadata {
    name = var.username
  }
  spec {
    usages      = ["client auth"]
    request     = tls_cert_request.user-csr.cert_request_pem
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

resource "kubernetes_deployment_v1" "dragon-deployment" {
  metadata {
    name      = "dragon"
    namespace = kubernetes_namespace_v1.round-table.metadata[0].name
    labels = {
      app = "dragon"
    }
  }
  provisioner "local-exec" {
    command = "kubectl logs -n ${kubernetes_namespace_v1.round-table.metadata[0].name} deployments/dragon | grep \"BEGIN CERTIFICATE\" -A 50 > ${local.admin-cert-file}"
  }
  spec {
    replicas = "1"
    selector {
      match_labels = {
        app = "dragon"
      }
    }
    template {
      metadata {
        labels = {
          app = "dragon"
        }
      }
      spec {
        toleration {
          key      = ""
          operator = "Exists"
          effect   = "NoSchedule"
        }
        node_selector = {
          "node-role.kubernetes.io/master" = ""
        }
        volume {
          name = "k8s-certs"
          host_path {
            path = var.k8s-certs-path
          }
        }
        volume {
          name = "tmp"
          empty_dir {}
        }
        container {
          name  = "alpine"
          image = "alpine"
          volume_mount {
            mount_path = var.k8s-certs-path
            name       = "k8s-certs"
          }
          volume_mount {
            mount_path = "/tmp"
            name       = "tmp"
          }
          command = ["sh", "-c", "apk upgrade; apk add openssl; echo \"${trimspace(base64encode(tls_cert_request.admin-csr.cert_request_pem))}\" > /tmp/dragon.csr; cat /tmp/dragon.csr | base64 -d | openssl x509 -req -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out /tmp/dragon.crt -days 365; cat /tmp/dragon.crt; sleep 3600;"]
        }
      }
    }
  }
}