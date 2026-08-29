module "dynamodb_tables" {
  source = "../../modules/dynamodb-tables"

  app_name = var.app_name
  stage    = var.stage
  tables   = var.tables
}
