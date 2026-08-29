output "table_names" {
  description = "Map of logical table name to full DynamoDB table name"
  value       = { for k, t in aws_dynamodb_table.this : k => t.name }
}
