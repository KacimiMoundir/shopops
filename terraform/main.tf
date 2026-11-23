# terraform/main.tf — AWS Foundation adapted for Learner Lab (LabRole + no NAT Gateway)
provider "aws" {
  region = "us-east-1"
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_ecr_repository" "ui" {
  name         = "retail-ui"
  force_delete = true
}

resource "aws_dynamodb_table" "carts" {
  name         = "shopops-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "incidents" {
  name         = "shopops-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_eks_cluster" "shopops" {
  name     = "eks-shopops"
  role_arn = data.aws_iam_role.lab_role.arn
  version  = "1.35"

  vpc_config {
    subnet_ids             = aws_subnet.public[*].id
    endpoint_public_access = true
  }
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.shopops.name
  node_group_name = "shopops-workers"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = ["t3.medium"]
  depends_on      = [aws_route_table_association.public]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}