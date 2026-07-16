module "chatbot_attachments_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name               = var.chatbot_attachments_bucket_name
  app_name                  = var.app_name
  stage                     = var.stage
  enable_public_read        = var.enable_public_read
  lambda_execution_role_arn = var.lambda_execution_role_arn
}
