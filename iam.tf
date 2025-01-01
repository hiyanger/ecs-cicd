# IDプロバイダの作成
data "http" "github_actions_openid_configuration" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "tls_certificate" "github_actions" {
  url = jsondecode(data.http.github_actions_openid_configuration.response_body).jwks_uri
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.github_actions.certificates[*].sha1_fingerprint
}

# IAMロール作成
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 特定のリポジトリの特定のブランチからのみ認証を許可する
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:hiyanger/gha-image-push:ref:refs/heads/master"]
    }
  }
}

resource "aws_iam_role" "oidc" {
  name               = "oidc-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAMポリシー
resource "aws_iam_role_policy" "ecs_cicd" {
  name   = "ecs_cicd"
  role   = aws_iam_role.oidc.name
  policy = data.aws_iam_policy_document.ecs_cicd.json
}

data "aws_iam_policy_document" "ecs_cicd" {

  # ECRログイン
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # docker push
  statement {
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    resources = ["arn:aws:ecr:ap-northeast-1:${var.account_id}:repository/ecs-cicd"]
  }

  # S3へファイル配置
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::ecs-cicd-migration-bucket-20241231",
      "arn:aws:s3:::ecs-cicd-migration-bucket-20241231/*"
    ]
  }
}

# パイプライン用
# IAMロール
resource "aws_iam_role" "ecs_cicd" {
  name = "ecs-cicd-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "codebuild.amazonaws.com",
            "codepipeline.amazonaws.com",
            "codedeploy.amazonaws.com",
            "ecs.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 管理者権限ポリシーをアタッチ（適宜変更する）
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.ecs_cicd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}