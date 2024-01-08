
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

resource "kubernetes_service" "awx_service_lb" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.awx_namespace]
  metadata {
    name      = "service-loadbalancer"
    namespace = kubernetes_namespace.awx_namespace.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
        "app.kubernetes.io/component"   = "awx"
        "app.kubernetes.io/managed-by"  = "awx-operator"
        "app.kubernetes.io/name"        = "awx-web"
    }

    port {
      protocol   = "TCP"
      port       = 80
      target_port = 8052
    }
  }
}

data "kubernetes_service" "awx_lb_details" {
  metadata {
    name = kubernetes_service.awx_service_lb.metadata[0].name
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