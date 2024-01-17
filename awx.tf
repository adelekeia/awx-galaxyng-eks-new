resource "tls_private_key" "lbtls" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "lbtls" {
  private_key_pem = tls_private_key.lbtls.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "lbtls" {
  private_key      = tls_private_key.lbtls.private_key_pem
  certificate_body = tls_self_signed_cert.lbtls.cert_pem
}

resource "kubernetes_namespace" "awx_namespace" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes]
  metadata {
    name = "awx"
  }
}

resource "helm_release" "my_awx_operator" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, kubernetes_namespace.awx_namespace]
  name       = "my-awx-operator"
  chart      = "awx-operator/awx-operator"
  namespace  = "awx"

  set {
    name  = "AWX.postgres.password"
    value = "postgres"
  }

  set {
    name  = "AWX.postgres.host"
    value = aws_rds_cluster.postgres_cluster.endpoint
  }

  values = [
    file("${path.module}/awx-operator/config.yaml")
  ]
}

/*
resource "kubernetes_service" "awx_service_lb" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.awx_namespace]
  metadata {
    name      = "service-loadbalancer"
    namespace = kubernetes_namespace.awx_namespace.metadata[0].name

    annotations = {
      foo = "bar"
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "service.beta.kubernetes.io/aws-load-balancer-tls-cert" = aws_acm_certificate.lbtls.arn
      "service.beta.kubernetes.io/aws-load-balancer-tls-ports" = "https"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
        "app.kubernetes.io/component"   = "awx"
        "app.kubernetes.io/managed-by"  = "awx-operator"
        "app.kubernetes.io/name"        = "awx-web"
    }

    port {
      name       = "https"
      protocol   = "TCP"
      port       = 443
      target_port = 8052
    }
  }
}
*/

data "kubernetes_service" "awx_lb_details" {
  metadata {
    name = "awx-service"
    namespace = kubernetes_namespace.awx_namespace.metadata[0].name
  }
}


data "kubernetes_secret" "awx_password_details" {
  metadata {
    name = "awx-admin-password"
    namespace = kubernetes_namespace.awx_namespace.metadata[0].name
  }
}

# Display AWX url, username and password
output "awx_login_details_display" {
  value = "############################################## \nLogin to AWX with below details \nURL: http://${data.kubernetes_service.awx_lb_details.status.0.load_balancer.0.ingress.0.hostname} \nUsername: admin \nPassword: ${nonsensitive(data.kubernetes_secret.awx_password_details.data.password)} \n##############################################"
}

// 