variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name used for tagging/naming"
  default     = "event-driven-cloud-platform"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/prod)"
  default     = "dev"
}
