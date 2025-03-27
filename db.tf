# RDS
resource "aws_db_instance" "lab-mysql" {
  identifier              = "lab-mysql"
  engine                  = "mysql"
  engine_version          = "8.4.3"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp3"
  username                = local.db_creds.username
  password                = local.db_creds.password
  multi_az                = true
  db_subnet_group_name    = aws_db_subnet_group.lab-mysql-subnet-group.name
  vpc_security_group_ids  = [aws_security_group.lab-mysql-sg.id]
  skip_final_snapshot     = true
  storage_encrypted       = true
  backup_retention_period = 5

  publicly_accessible = false
  apply_immediately   = false
  maintenance_window  = "sun:03:00-sun:04:00"
  backup_window       = "01:00-02:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
}

