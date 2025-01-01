# ECS
resource "aws_security_group" "ecs_cicd" {
  name        = "ecs-cicd-sg"
  description = "Allow HTTP access"
  vpc_id      = aws_vpc.ecs_cicd.id

  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ecs-cicd-sg"
  }
}

# RDS
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Allow access to RDS"
  vpc_id      = aws_vpc.ecs_cicd.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.rds_allow_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}