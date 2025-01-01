# VPC
resource "aws_vpc" "ecs_cicd" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true # DNS 解決を有効化
  enable_dns_hostnames = true # DNS ホスト名を有効化

  tags = {
    Name = "ecs-cicd-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "ecs_cicd" {
  vpc_id = aws_vpc.ecs_cicd.id
  tags = {
    Name = "ecs-cicd-igw"
  }
}

# パブリックサブネット
resource "aws_subnet" "ecs_cicd_public_1" {
  vpc_id                  = aws_vpc.ecs_cicd.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = "ecs-cicd-public-1"
  }
}

resource "aws_subnet" "ecs_cicd_public_2" {
  vpc_id                  = aws_vpc.ecs_cicd.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"

  tags = {
    Name = "ecs-cicd-public-2"
  }
}

# ルートテーブル
resource "aws_route_table" "ecs_cicd" {
  vpc_id = aws_vpc.ecs_cicd.id
  tags = {
    Name = "ecs-cicd-route"
  }
}

resource "aws_route" "ecs-cicd" {
  route_table_id         = aws_route_table.ecs_cicd.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecs_cicd.id
}

resource "aws_route_table_association" "ecs_cicd_1" {
  subnet_id      = aws_subnet.ecs_cicd_public_1.id
  route_table_id = aws_route_table.ecs_cicd.id
}

resource "aws_route_table_association" "ecs_cicd_2" {
  subnet_id      = aws_subnet.ecs_cicd_public_2.id
  route_table_id = aws_route_table.ecs_cicd.id
}

/*
# プライベートサブネット（RDS）
resource "aws_subnet" "ecs_cicd_private_1" {
  vpc_id                  = aws_vpc.ecs_cicd.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = "ecs-cicd-private-1"
  }
}

resource "aws_subnet" "ecs_cicd_private_2" {
  vpc_id                  = aws_vpc.ecs_cicd.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"

  tags = {
    Name = "ecs-cicd-private-2"
  }
}

# プライベートサブネット用ルートテーブルの作成
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ecs_cicd.id

  tags = {
    Name = "private-route-table"
  }
}

# サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "ecs_cicd_private_1" {
  subnet_id      = aws_subnet.ecs_cicd_private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "ecs_cicd_private_2" {
  subnet_id      = aws_subnet.ecs_cicd_private_2.id
  route_table_id = aws_route_table.private.id
}

*/

# ALB
resource "aws_lb" "ecs_cicd" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_cicd.id]
  subnets            = [aws_subnet.ecs_cicd_public_1.id, aws_subnet.ecs_cicd_public_2.id]

  tags = {
    Name = "ecs-alb"
  }
}

# ターゲットグループの作成
resource "aws_lb_target_group" "ecs_cicd_blue" {
  name        = "ecs-cicd-target-group-blue"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.ecs_cicd.id

  tags = {
    Name = "ecs-cicd-target-group-blue"
  }
}

resource "aws_lb_target_group" "ecs_cicd_green" {
  name        = "ecs-cicd-target-group-green"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.ecs_cicd.id

  tags = {
    Name = "ecs-cicd-target-group-green"
  }
}

# ALBリスナーの作成
resource "aws_lb_listener" "ecs_cicd" {
  load_balancer_arn = aws_lb.ecs_cicd.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_cicd_blue.arn
  }
}