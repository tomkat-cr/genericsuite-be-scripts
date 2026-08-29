data "terraform_remote_state" "domain" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "${var.stage}/domain.tfstate"
    region = var.aws_region
  }
}

locals {
  ecr_repository_name = "${var.lambda_function_name}-ec2"
}

module "ec2_alb" {
  source = "../../modules/ec2-alb"

  app_name            = var.app_name
  stage               = var.stage
  aws_region          = var.aws_region
  aws_account_id      = var.aws_account_id
  ecr_repository_name = local.ecr_repository_name
  ecr_image_uri       = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.ecr_repository_name}"
  ecr_image_tag       = var.ecr_image_tag
  domain_name         = data.terraform_remote_state.domain.outputs.domain_name
  hosted_zone_id      = data.terraform_remote_state.domain.outputs.hosted_zone_id
  certificate_arn     = data.terraform_remote_state.domain.outputs.certificate_arn
  s3_bucket_name      = var.chatbot_attachments_bucket_name
  kms_key_alias       = var.kms_key_alias
  asm_secrets_arn     = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.app_name}-${var.stage}-secrets*"
  asm_envs_arn        = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.app_name}-${var.stage}-envs*"
  ssh_ingress_cidr    = var.ssh_ingress_cidr
}
