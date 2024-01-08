# EFS File System
resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"
}

# EFS Mount Targets in each EKS subnet
resource "aws_efs_mount_target" "efs_mt" {
  count           = length(aws_subnet.eks_subnet)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.eks_subnet[count.index].id
  security_groups = [aws_security_group.eks_worker_sg.id]
}

