locals {
  is_image = var.package_type == "Image"
}

resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-tf-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.function_name}-tf-execution-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject", "s3:PutObjectAcl", "s3:GetObject",
          "s3:GetObjectAcl", "s3:DeleteObject",
        ]
        Resource = "arn:aws:s3:::${var.chatbot_attachments_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
        ]
        Resource = "arn:*:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.asm_secrets_arn, var.asm_envs_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey*", "kms:CreateGrant"]
        Resource = "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
          "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable", "dynamodb:ListTables",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.app_name}_${var.stage}_*"
      },
    ]
  })
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = "${var.app_name}-backend-${var.stage}"
  role          = aws_iam_role.lambda.arn
  package_type  = var.package_type
  memory_size   = var.memory_size
  timeout       = var.timeout

  image_uri        = local.is_image ? var.image_uri : null
  filename         = local.is_image ? null : var.zip_path
  handler          = local.is_image ? null : var.handler
  runtime          = local.is_image ? null : var.runtime
  source_code_hash = local.is_image ? null : filebase64sha256(var.zip_path)

  environment {
    variables = var.environment_variables
  }

  tracing_config {
    mode = "PassThrough"
  }
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${var.app_name}-backend-${var.stage}"

  endpoint_configuration {
    types = ["EDGE"]
  }

  binary_media_types = var.binary_media_types
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.this.invoke_arn
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.this.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.root.uri,
      aws_api_gateway_integration.proxy.uri,
      aws_api_gateway_resource.proxy.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.root,
    aws_api_gateway_integration.proxy,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}

# --- Optional custom domain ---

resource "aws_api_gateway_domain_name" "this" {
  count = var.domain_name != "" ? 1 : 0

  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = var.domain_name != "" ? 1 : 0

  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
}

resource "aws_route53_record" "this" {
  count = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_api_gateway_domain_name.this[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.this[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}
