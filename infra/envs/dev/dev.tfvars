project_name = "almanac"
aws_region   = "us-east-1"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = "256"
task_memory     = "512"
desired_count   = 1

# --- dev DB: small instance, short retention, deletion protection OFF ---
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "almanac"
db_username          = "app_admin"
# db_password is intentionally NOT stored here - pass it via
# TF_VAR_db_password or -var="db_password=..." / a secrets manager.
db_backup_retention_period = 1
db_deletion_protection     = false
db_skip_final_snapshot     = true
db_multi_az                = false
