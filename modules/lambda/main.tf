variable "function_name" { type = string }
variable "source_file"   { type = string }
variable "db_host"       { type = string }
variable "db_name"       { type = string }
variable "db_user"       { type = string }
variable "db_pass"       { type = string }
variable "s3_bucket"     { type = string }
variable "s3_bucket_arn" { type = string }
variable "vpc_id"        { type = string }
variable "subnet_ids"    { type = list(string) }

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/app.zip"
}

resource "aws_lambda_layer_version" "psycopg2" {
  filename            = "${path.root}/../../layers/psycopg2-layer.zip"
  layer_name          = "psycopg2-binary"
  compatible_runtimes = ["python3.12"]
}

resource "aws_security_group" "lambda_sg" {
  name   = "${var.function_name}-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3_access_policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${var.s3_bucket_arn}/*"
    }]
  })
}

resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  layers           = [aws_lambda_layer_version.psycopg2.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST   = split(":", var.db_host)[0]
      DB_NAME   = var.db_name
      DB_USER   = var.db_user
      DB_PASS   = var.db_pass
      S3_BUCKET = var.s3_bucket
    }
  }
}

output "invoke_arn"    { value = aws_lambda_function.api_handler.invoke_arn }
output "function_name" { value = aws_lambda_function.api_handler.function_name }
output "lambda_sg_id"  { value = aws_security_group.lambda_sg.id }  