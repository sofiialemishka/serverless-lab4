provider "aws" {
  region = "eu-central-1"
}

locals {
  prefix = "lemishka-sofiia-08"
}

resource "aws_s3_bucket" "logs" {
  bucket        = "${local.prefix}-logs"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "archive-logs"
    status = "Enabled"
    filter {
      prefix = ""
    }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

module "database" {
  source      = "../../modules/rds"
  db_name     = "${local.prefix}-db"
  db_username = "dbuser"
  db_password = var.db_password
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids
}

module "backend" {
  source        = "../../modules/lambda"
  function_name = "${local.prefix}-api-handler"
  source_file   = "${path.root}/../../src/app.py"
  db_host       = module.database.endpoint
  db_name       = module.database.db_name
  db_user       = "dbuser"
  db_pass       = var.db_password
  s3_bucket     = aws_s3_bucket.logs.bucket
  s3_bucket_arn = aws_s3_bucket.logs.arn
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
}

module "api" {
  source               = "../../modules/api_gateway"
  api_name             = "${local.prefix}-http-api"
  lambda_invoke_arn    = module.backend.invoke_arn
  lambda_function_name = module.backend.function_name
}

output "api_url" {
  value = module.api.api_endpoint
}