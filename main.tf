terraform {
  backend "remote" {
    organization = "tf-organization"

    workspaces {
      name = "tf-workspace-here"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# Create new snapshot
resource "aws_db_cluster_snapshot" "snapshot" {
  db_cluster_identifier = "cluster name for create snapshot"
  db_cluster_snapshot_identifier = "cluster-1-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"
  lifecycle {
    create_before_destroy = true
  }
}

# Get latest snapshot from production DB
data "aws_db_cluster_snapshot" "db_snapshot" {
    most_recent = true
    db_cluster_identifier = "cluster name"
    depends_on = [aws_db_cluster_snapshot.snapshot]
}

# Create new BI DB 
resource "aws_rds_cluster" "snapshot-cluster-lastest" {
  depends_on                          = [data.aws_db_cluster_snapshot.db_snapshot, aws_db_cluster_snapshot.snapshot]
  cluster_identifier                  = "snapshot-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"
  cluster_identifier_prefix           = null
  cluster_members                     = []
  apply_immediately                   = true
  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b",
    "ap-southeast-1c"
  ]
  backtrack_window                    = 0
  backup_retention_period             = 1
  copy_tags_to_snapshot               = false
  db_cluster_parameter_group_name     = "default.aurora5.6"
  db_subnet_group_name                = "default"
  deletion_protection                 = false
  enable_http_endpoint                = false
  enabled_cloudwatch_logs_exports     = []
  engine                              = "aurora"
  engine_mode                         = "serverless"
  engine_version                      = aws_db_cluster_snapshot.db_snapshot.engine_version
  final_snapshot_identifier           = null
  global_cluster_identifier           = ""
  iam_database_authentication_enabled = false
  iam_roles                           = []
  master_username                     = "username here"
  master_password                     = "password here"
  port                                = 3306
  preferred_backup_window             = ""
  preferred_maintenance_window        = ""
  replication_source_identifier       = ""
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 2
    min_capacity             = 1
    seconds_until_auto_pause = 300
    timeout_action           = "RollbackCapacityChange"
  }
  skip_final_snapshot                 = true
  snapshot_identifier                 = data.aws_db_cluster_snapshot.db_snapshot.id
  source_region                       = null
  storage_encrypted                   = true
  tags                                = {}
  timeouts {
      create = null
      delete = null
      update = null
  }
  vpc_security_group_ids = [
    "Your SG Here",
    "Your SG Here"
  ]
  lifecycle {
    create_before_destroy = true
  }
}

# Update Route53 Record
resource "aws_route53_record" "www" {
  depends_on = [data.aws_db_cluster_snapshot.db_snapshot, aws_db_cluster_snapshot.snapshot, aws_rds_cluster.snapshot-cluster-lastest]
  name       = "dbsnapshot.yourdomain.com"
  records    = [aws_rds_cluster.snapshot-cluster-lastest.endpoint]
  ttl        = 300
  type       = "CNAME"
  zone_id    = "Route53 Zone ID Here"
}
