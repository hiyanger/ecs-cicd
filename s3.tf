# アーティファクト用バケット
resource "aws_s3_bucket" "ecs_cicd" {
  bucket = "ecs-cicd-artifacts-20241230"
}

# マイグレーションSQL配置用バケット
resource "aws_s3_bucket" "ecs_cicd_migration" {
  bucket = "ecs-cicd-migration-bucket-20241231"
}

resource "aws_s3_bucket_versioning" "versioning_migration" {
  bucket = aws_s3_bucket.ecs_cicd.id
  versioning_configuration {
    status = "Enabled"
  }
}

# appspec/task_definition 配置用バケット
resource "aws_s3_bucket" "ecs_cicd_deploy" {
  bucket = "ecs-cicd-appspec-task-bucket-20241231"
}

# appspec
resource "aws_s3_object" "appspec" {
  bucket = aws_s3_bucket.ecs_cicd_deploy.id
  key    = "appspec.yml"
  content = templatefile("s3/appspec.yml", {
    account_id = "${var.account_id}"
  })
  etag = filemd5("s3/appspec.yml")
}

/*
# task_def
resource "aws_s3_object" "task_def" {
  bucket = aws_s3_bucket.ecs_cicd_deploy.id
  key    = "task_def.json"
  content = templatefile("s3/task_def.json",{
    account_id = "${var.account_id}"
  })
  etag = filemd5("s3/task_def.json")
}
*/