# CodeBuild
resource "aws_codebuild_project" "ecs_cicd_migration" {
  name         = "rds-migration"
  service_role = aws_iam_role.ecs_cicd.arn

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec.yml")
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    # 環境変数
    environment_variable {
      name  = "DB_HOST"
      value = var.rds_endpoint
    }

    environment_variable {
      name  = "DB_USER"
      value = var.rds_user
    }

    environment_variable {
      name  = "DB_PASS"
      value = var.rds_password # Secrets Manager推奨
    }
  }
}

# CodeDeploy
resource "aws_codedeploy_app" "ecs_cicd" {
  compute_platform = "ECS"
  name             = "ecs-cicd"
}

# デプロイメントグループ
resource "aws_codedeploy_deployment_group" "ecs_cicd" {
  app_name               = aws_codedeploy_app.ecs_cicd.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "ecs_cicd"
  service_role_arn       = aws_iam_role.ecs_cicd.arn

  # 自動ロールバック
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # Blue/Greenデプロイメント
  blue_green_deployment_config {

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    # Blueインスタンス（旧バージョン）の処理
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  # デプロイスタイルの設定
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  # ECSサービスの関連付け
  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_cicd.name
    service_name = aws_ecs_service.ecs_cicd.name
  }

  # ロードバランサー情報の設定
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.ecs_cicd.arn]
      }

      # Blueターゲットグループ
      target_group {
        name = aws_lb_target_group.ecs_cicd_blue.name
      }

      # Greenターゲットグループ
      target_group {
        name = aws_lb_target_group.ecs_cicd_green.name
      }
    }
  }
}

# CodePipeline
resource "aws_codepipeline" "ecs_cicd" {
  name          = "ecs-cicd-pipeline"
  pipeline_type = "V2"
  role_arn      = aws_iam_role.ecs_cicd.arn

  artifact_store {
    location = aws_s3_bucket.ecs_cicd.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "ECRTrigger"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_ecr_repository.ecs_cicd.name
        ImageTag       = "latest"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildMigration"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.ecs_cicd_migration.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.ecs_cicd.name
        DeploymentGroupName = aws_codedeploy_deployment_group.ecs_cicd.deployment_group_name
        #TaskDefinitionTemplateArtifact = "build_output"
        #TaskDefinitionTemplatePath     = "task_def.json"
        #AppSpecTemplateArtifact        = "build_output"
        #AppSpecTemplatePath            = "appspec.yml"
        #Image1ArtifactName  = "source_output"
        #Image1ContainerName = "IMAGE1_NAME"
      }
    }
  }
}