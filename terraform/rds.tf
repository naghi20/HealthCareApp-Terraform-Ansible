resource "aws_db_subnet_group" "db" {
  name       = "lab-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "app_db" {
  identifier             = "lab-app-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  username               = var.db_username
  password               = var.db_password
  multi_az               = true
  skip_final_snapshot    = true
  backup_retention_period = 7
  publicly_accessible    = false
}
