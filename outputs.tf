output "table_name" {
  description = "Table name."
  value       = join("", aws_dynamodb_table.default.*.name)
}

output "table_id" {
  description = "Table ID."
  value       = join("", aws_dynamodb_table.default.*.id)
}

output "table_arn" {
  description = "Table ARN."
  value       = join("", aws_dynamodb_table.default.*.arn)
}

output "table_stream_arn" {
  description = "The ARN of the Table Stream. Only available when stream is enabled"
  value       = join("", aws_dynamodb_table.default.*.stream_arn)
}

output "table_stream_label" {
  description = "Table Stream Label. A timestamp, in ISO 8601 format, for stream. The combination of AWS customer ID, table name and this field is guaranteed to be unique, and can be used for creating CloudWatch alarms. Only available when stream is enabled"
  value       = join("", aws_dynamodb_table.default.*.stream_label)
}

