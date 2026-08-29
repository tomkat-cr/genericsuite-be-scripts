module "lambda_repository" {
  source = "../../modules/ecr-repository"

  repository_name = var.lambda_function_name
  images_to_keep  = var.images_to_keep
}

module "ec2_repository" {
  source = "../../modules/ecr-repository"
  count  = var.create_ec2_repository ? 1 : 0

  repository_name = "${var.lambda_function_name}-ec2"
  images_to_keep  = var.images_to_keep
}
