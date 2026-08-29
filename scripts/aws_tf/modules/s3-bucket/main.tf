data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = {
    comment = "Created by OpenTofu in ${var.stage} environment."
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = !var.enable_public_read
  restrict_public_buckets = !var.enable_public_read
}

locals {
  principals = compact([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
    var.lambda_execution_role_arn,
  ])
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "Allow${var.app_name}${var.stage}ReadAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.principals
    }
    actions = [
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:GetObjectTagging",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  statement {
    sid    = "Allow${var.app_name}${var.stage}WriteAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.principals
    }
    actions = [
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  dynamic "statement" {
    for_each = var.enable_public_read ? [1] : []
    content {
      sid    = "AllowPublicRead"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}
