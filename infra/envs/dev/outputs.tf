output "bronze_bucket_name" {
  value = aws_s3_bucket.bronze.bucket
}

output "silver_bucket_name" {
  value = aws_s3_bucket.silver.bucket
}

output "events_table_name" {
  value = aws_dynamodb_table.events.name
}

output "queue_url" {
  value = aws_sqs_queue.queue.url
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}
