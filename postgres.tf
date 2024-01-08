resource "aws_rds_cluster" "postgres_cluster" {
  cluster_identifier      = "postgres-cluster-1"
  engine                  = "postgres"
  engine_version          = "13.7"
  database_name           = "awx"
  master_username         = "postgres"
  master_password         = "postgres"
  allocated_storage       = 100
  db_cluster_instance_class = "db.r6gd.xlarge"
  storage_type            = "io1"
  availability_zones      = ["us-east-1a"]
  iops                    = 1000
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.postgres.name
  vpc_security_group_ids  = [aws_security_group.postgres.id]

  lifecycle {
    ignore_changes = [
      engine_version,
      allocated_storage,
      availability_zones,
      // Add other attributes as needed
    ]
  }
}

