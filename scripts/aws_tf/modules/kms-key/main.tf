data "aws_caller_identity" "current" {}

locals {
  ec2_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  admin_actions = [
    "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
    "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
    "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:GenerateDataKey",
  ]
  use_actions = [
    "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
    "kms:GenerateDataKey*", "kms:DescribeKey",
  ]
  grant_actions = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
}

resource "aws_iam_role" "key_admin" {
  name               = "${var.alias}-key-admin-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy" "key_admin_policy" {
  name = "KeyAdminPolicy"
  role = aws_iam_role.key_admin.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = local.admin_actions, Resource = "*" }]
  })
}

resource "aws_iam_role" "use_key" {
  name               = "${var.alias}-use-key-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy" "use_key_policy" {
  name = "UseKeyPolicy"
  role = aws_iam_role.use_key.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = local.use_actions, Resource = "*" }]
  })
}

resource "aws_iam_role" "attach_key" {
  name               = "${var.alias}-attach-key-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy" "attach_key_policy" {
  name = "AttachKeyPolicy"
  role = aws_iam_role.attach_key.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = local.grant_actions, Resource = "*" }]
  })
}

resource "aws_iam_role" "asg" {
  name = "${var.alias}-tf-asg-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "autoscaling.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_kms_key" "this" {
  description = "KMS key for encrypting Secrets Manager secrets and other resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow access for Key Administrators"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.key_admin.arn }
        Action    = local.admin_actions
        Resource  = "*"
      },
      {
        Sid       = "Allow use of the key"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.use_key.arn }
        Action    = local.use_actions
        Resource  = "*"
      },
      {
        Sid       = "Allow attachment of persistent resources"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.attach_key.arn }
        Action    = local.grant_actions
        Resource  = "*"
      },
      {
        Sid       = "Allow use of the key for EBS volumes"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = local.use_actions
        Resource  = "*"
      },
      {
        Sid       = "Allow EC2 attachment of persistent resources"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = local.grant_actions
        Resource  = "*"
        Condition = { Bool = { "kms:GrantIsForAWSResource" = true } }
      },
      {
        Sid       = "Allow use of the key for ASG"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.asg.arn }
        Action    = local.use_actions
        Resource  = "*"
      },
      {
        Sid       = "Allow attachment of persistent resources for ASG"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.asg.arn }
        Action    = local.grant_actions
        Resource  = "*"
        Condition = { Bool = { "kms:GrantIsForAWSResource" = true } }
      },
    ]
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}
