output "table_names" {
  description = "Created DynamoDB table names"
  value       = module.dynamodb_tables.table_names
}
