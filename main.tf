terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "default"

  default_tags {
    tags = var.default_tags
  }
}


provider "kubernetes" {
  host                   = aws_eks_cluster.awx_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.awx_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.awx_cluster.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.awx_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.awx_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.awx_cluster.token
  }
}