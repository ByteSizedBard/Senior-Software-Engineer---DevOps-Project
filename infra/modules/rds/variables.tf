variable "name_prefix" {
  type = string
}

variable "engine" {
  description = "postgres or mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
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
  description = "Master password. In real usage pull this from AWS Secrets Manager / SSM, never commit it."
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when this instance is destroyed. Deliberately independent of deletion_protection: turning deletion_protection off to allow a destroy shouldn't silently also skip the final snapshot - the two are separate decisions."
  type        = bool
  default     = true
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
