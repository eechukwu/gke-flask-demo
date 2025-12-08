variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
}

variable "project_name" {
  description = "Logical name for this project (used in tags and resource names)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, stage, prod)"
  type        = string
}
