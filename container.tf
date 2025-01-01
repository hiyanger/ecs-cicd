# ECR
resource "aws_ecr_repository" "ecs_cicd" {
  name                 = "ecs-cicd"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECSクラスター
resource "aws_ecs_cluster" "ecs_cicd" {
  name = "ecs-cicd-cluster"
}

# ECSタスク定義
resource "aws_ecs_task_definition" "ecs_cicd" {
  family                   = "ecs-cicd-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "ecs-cicd-container"
      image = "${var.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-cicd:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_cicd.arn
}

# ECSサービス
resource "aws_ecs_service" "ecs_cicd" {
  name            = "ecs-cicd-service"
  cluster         = aws_ecs_cluster.ecs_cicd.id
  task_definition = aws_ecs_task_definition.ecs_cicd.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.ecs_cicd_public_1.id, aws_subnet.ecs_cicd_public_2.id]
    security_groups  = [aws_security_group.ecs_cicd.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_cicd_blue.arn
    container_name   = "ecs-cicd-container"
    container_port   = 80
  }
}
