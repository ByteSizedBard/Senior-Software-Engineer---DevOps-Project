variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "container_image" {
  description = "Any simple image, e.g. nginx or a placeholder backend"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "db_host" {
  description = "RDS endpoint, injected as an env var into the container"
  type        = string
  default     = ""
}

variable "db_name" {
  type    = string
  default = ""
}

variable "aws_region" {
  description = "Passed in as a variable (not looked up via the aws_region data source) so `terraform plan` doesn't require real AWS credentials"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
