module "lambda_api" {
  source = "../../modules/lambda-api"

  function_name                   = var.lambda_function_name
  app_name                        = var.app_name
  stage                           = var.stage
  aws_region                      = var.aws_region
  aws_account_id                  = var.aws_account_id
  package_type                    = var.package_type
  image_uri                       = var.package_type == "Image" ? "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.lambda_function_name}:${var.ecr_image_tag}" : ""
  zip_path                        = var.zip_path
  handler                         = var.handler
  environment_variables           = var.environment_variables
  chatbot_attachments_bucket_name = var.chatbot_attachments_bucket_name
  asm_secrets_arn                 = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.app_name}-${var.stage}-secrets*"
  asm_envs_arn                    = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.app_name}-${var.stage}-envs*"
  domain_name                     = var.api_domain_name
  certificate_arn                 = var.certificate_arn
  hosted_zone_id                  = var.hosted_zone_id
}
