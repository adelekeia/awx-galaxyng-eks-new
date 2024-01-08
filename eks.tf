resource "aws_eks_cluster" "awx_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }
}

resource "aws_eks_node_group" "awx_nodes" {
  cluster_name    = aws_eks_cluster.awx_cluster.name
  node_group_name = "awx"
  node_role_arn   = aws_iam_role.eks_worker_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  # Attach the security group to the node group
  remote_access {
    ec2_ssh_key               = aws_key_pair.keypair.key_name
    source_security_group_ids = [aws_security_group.eks_worker_sg.id]
  }
}

data "aws_eks_cluster" "awx_cluster" {
  name = aws_eks_cluster.awx_cluster.name
}

data "aws_eks_cluster_auth" "awx_cluster" {
  name = aws_eks_cluster.awx_cluster.name
}