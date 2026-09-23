variable "name_prefix" {
  description = "Prefix used for naming all network resources (e.g. myapp-dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Explicit list of AZs to use (kept as a plain variable, not an aws_availability_zones data source, so `terraform plan` works with no real AWS credentials in CI)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "container_port" {
  description = "Port the application container listens on (used for ECS SG ingress from ALB)"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Port the database listens on (used for RDS SG ingress from ECS)"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
