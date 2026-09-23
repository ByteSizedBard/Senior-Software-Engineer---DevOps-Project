variable "project_name" {
  type    = string
  default = "almanac"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = string
  default = "512"
}

variable "task_memory" {
  type    = string
  default = "1024"
}

variable "desired_count" {
  type    = number
  default = 2
}

# --- Database sizing: prod = larger + protected ---
variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_name" {
  type    = string
  default = "almanac"
}

variable "db_username" {
  type      = string
  default   = "app_admin"
  sensitive = true
}

variable "db_password" {
  description = "Plan-only placeholder; override securely for real deployments (TF_VAR_db_password, -var, or a secrets manager)."
  type        = string
  sensitive   = true
  default     = "assessment-plan-only-password"
}

variable "db_backup_retention_period" {
  type    = number
  default = 30
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = false
}

variable "db_multi_az" {
  type    = bool
  default = true
}
