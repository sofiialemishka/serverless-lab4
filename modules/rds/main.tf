variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "vpc_id"     { type = string }
variable "subnet_ids" { type = list(string) }

resource "aws_db_subnet_group" "main" {
  name       = "${var.db_name}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds_sg" {
  name   = "${var.db_name}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier             = var.db_name
  engine                 = "postgres"
  engine_version         = "15.10"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = replace(var.db_name, "-", "_")
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

output "endpoint" { value = aws_db_instance.main.address }
output "db_name"  { value = aws_db_instance.main.db_name }
