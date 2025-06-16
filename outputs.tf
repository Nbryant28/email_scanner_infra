output "dynamodb_table_name" {
  value = aws_dynamodb_table.email_tracker_capsules.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.email_tracker_uploads.id
}


