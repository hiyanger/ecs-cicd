resource "aws_db_instance" "default" {
  identifier           = "ecs-cicd-rds"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = var.rds_user
  password             = var.rds_password # 管理者パスワード (シークレットで管理推奨)
  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = true # パブリックアクセスの有効/無効（テスト簡易化のために有効）
  multi_az             = false
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.ecs_cicd.name

  tags = {
    Name = "ecs-cicd-rds"
  }
}

# RDSサブネットグループ
resource "aws_db_subnet_group" "ecs_cicd" {
  name = "ecs_cicd"
  subnet_ids = [
    aws_subnet.ecs_cicd_public_1.id,
    aws_subnet.ecs_cicd_public_2.id
  ]

  tags = {
    Name = "rds-subnet-group"
  }
}

