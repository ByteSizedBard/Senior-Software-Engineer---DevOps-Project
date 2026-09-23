project_name = "almanac"
aws_region   = "us-east-1"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = "512"
task_memory     = "1024"
desired_count   = 2

# --- prod DB: larger instance, long retention, deletion protection ON ---
db_instance_class    = "db.r6g.large"
db_allocated_storage = 100
db_name              = "almanac"
db_username          = "app_admin"
# db_password is intentionally NOT stored here - pass it via
# TF_VAR_db_password or -var="db_password=..." / a secrets manager.
db_backup_retention_period = 30
db_deletion_protection     = true
db_skip_final_snapshot     = false
db_multi_az                = true
