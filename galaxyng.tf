resource "kubernetes_namespace" "pulp_namespace" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster]
  metadata {
    name = "pulp"
  }
}

resource "helm_release" "pulp" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.pulp_namespace]
  name        = "pulp"
  chart       = "https://github.com/pulp/pulp-k8s-resources/releases/download/1.0.1-beta.3/pulp-operator-0.1.0.tgz"
  namespace   = "pulp"
}

resource "kubernetes_persistent_volume" "efs_pv" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster]
  metadata {
    name = "efs-pv"
  }

  spec {
    capacity = {
      storage = "10Gi"
    }

    volume_mode = "Filesystem"
    access_modes = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name = "efs"

    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.efs.id  # Replace with your EFS Filesystem ID variable
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "efs_claim" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.pulp_namespace]
  metadata {
    name      = "efs-claim"
    namespace = kubernetes_namespace.pulp_namespace.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = "efs"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_service" "service_lb" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.pulp_namespace]
  metadata {
    name      = "service-loadbalancer"
    namespace = kubernetes_namespace.pulp_namespace.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app"                           = "pulp-web"
      "app.kubernetes.io/component"   = "web"
      "app.kubernetes.io/instance"    = "galaxy-web-${var.galaxy_ng_instance}"
      "app.kubernetes.io/managed-by"  = "galaxy-operator"
      "app.kubernetes.io/name"        = "galaxy-web"
      "app.kubernetes.io/part-of"     = "galaxy"
      "pulp_cr"                       = "${var.galaxy_ng_instance}"
    }

    port {
      protocol   = "TCP"
      port       = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_secret" "external_database" {
  depends_on  = [aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_namespace.pulp_namespace]

  metadata {
    name      = "external-database"
    namespace = kubernetes_namespace.pulp_namespace.metadata[0].name
  }

  data = {
    POSTGRES_HOST       = aws_rds_cluster.postgres_cluster.endpoint
    POSTGRES_PORT       = aws_rds_cluster.postgres_cluster.port
    POSTGRES_USERNAME   = aws_rds_cluster.postgres_cluster.master_username
    POSTGRES_PASSWORD   = aws_rds_cluster.postgres_cluster.master_password
    POSTGRES_DB_NAME    = aws_rds_cluster.postgres_cluster.database_name
    POSTGRES_SSLMODE    = "prefer"
  }
}

data "kubernetes_service" "lb_details" {
  metadata {
    name = kubernetes_service.service_lb.metadata[0].name
    namespace = kubernetes_namespace.pulp_namespace.metadata[0].name
  }
}

output "postgres_cluster_endpoint" {
  value = aws_rds_cluster.postgres_cluster.endpoint
}

output "aws_efs_file_system_efs_id" {
  value = aws_efs_file_system.efs.id
}

resource "local_file" "config_managed_yaml" {
  content  = templatefile("${path.module}/pulp-operator/config.yaml.tpl", { unmanaged_flag = "false", lb_hostname = data.kubernetes_service.lb_details.status.0.load_balancer.0.ingress.0.hostname, galaxy_ng_instance = var.galaxy_ng_instance })
  filename = "${path.module}/pulp-operator/config_managed.yaml"
}

resource "local_file" "config_unmanaged_yaml" {
  content  = templatefile("${path.module}/pulp-operator/config.yaml.tpl", { unmanaged_flag = "true", lb_hostname = data.kubernetes_service.lb_details.status.0.load_balancer.0.ingress.0.hostname, galaxy_ng_instance = var.galaxy_ng_instance })
  filename = "${path.module}/pulp-operator/config_unmanaged.yaml"
}

# Provisioner to run local commands
resource "null_resource" "custom_operator_install" {

  depends_on = [ helm_release.pulp, kubernetes_secret.external_database, aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_rds_cluster.postgres_cluster, kubernetes_service.service_lb] //, null_resource.csi_driver_install]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      export PATH="/usr/local/bin:$PATH"
      export PATH=$HOME/bin:$PATH
      aws eks --region '${var.region}' update-kubeconfig --name '${var.cluster_name}'
      
      kubectl apply -f ${local_file.config_managed_yaml.filename}
      kubectl apply -f ${local_file.config_unmanaged_yaml.filename}

      kubectl get deployment.apps/${var.galaxy_ng_instance}-api deployment.apps/${var.galaxy_ng_instance}-content deployment.apps/${var.galaxy_ng_instance}-worker -n ${kubernetes_namespace.pulp_namespace.metadata[0].name} -o yaml > pulp-operator/all-deploy.yaml
      sed -i '' -e '/resourceVersion:/d' -e 's/fsGroup: 700//g; s/runAsUser: 700//g' pulp-operator/all-deploy.yaml
      perl -0777 -i -pe 's/allowPrivilegeEscalation: false\n\s*capabilities:\n\s*drop:\n\s*-\sALL\n\s*runAsNonRoot: true\n\s*seccompProfile:\n\s*type: RuntimeDefault//gs' pulp-operator/all-deploy.yaml
      kubectl apply -f pulp-operator/all-deploy.yaml
    EOT
  }
}

# Provisioner to run local commands
/*
resource "null_resource" "csi_driver_install" {

  depends_on = [ aws_eks_cluster.awx_cluster, aws_eks_node_group.awx_nodes, aws_efs_mount_target.efs_mt]

  provisioner "local-exec" {
    command = <<-EOT
      export PATH="/usr/local/bin:$PATH"
      export PATH=$HOME/bin:$PATH
      aws eks --region '${var.region}' update-kubeconfig --name '${var.cluster_name}'
      
      kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=master"

    EOT
  }
}
*/

/*
data "kubernetes_secret" "password_details" {
  metadata {
    name = "${var.galaxy_ng_instance}-admin-password"
    namespace = kubernetes_namespace.pulp_namespace.metadata[0].name
  }
}

# Display AWX url, username and password
output "galaxy_login_details_display" {
  value = "############################################## \nLogin to Galaxy NG with below details \nURL: http://${data.kubernetes_service.lb_details.status.0.load_balancer.0.ingress.0.hostname} \nUsername: admin \nPassword: ${nonsensitive(data.kubernetes_secret.password_details.data.password)} \n##############################################"
}
*/