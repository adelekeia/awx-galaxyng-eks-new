resource "tls_private_key" "oskey" {
  algorithm = "RSA"
}

resource "local_file" "key" {
  content  = tls_private_key.oskey.private_key_pem
  filename = "key.pem"
}

resource "aws_key_pair" "keypair" {
  key_name   = "key"
  public_key = tls_private_key.oskey.public_key_openssh
}

resource "aws_security_group" "eks_worker_sg" {
  name        = "eks-worker-sg"
  description = "Security group for EKS worker nodes to allow port 80"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "postgres" {
  name        = "allow-1"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust this to a more restricted CIDR block
  }
}
