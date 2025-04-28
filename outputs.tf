# Outputs
output "document_bucket_name" {
  description = "Name of the S3 bucket for storing PDFs"
  value       = aws_s3_bucket.document_bucket.bucket
}

output "website_bucket_name" {
  description = "Name of the S3 bucket for website hosting"
  value       = aws_s3_bucket.website_bucket.bucket
}

output "website_url" {
  description = "URL of the website"
  value       = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "api_endpoint" {
  description = "Endpoint URL of the API"
  value       = "https://${aws_api_gateway_rest_api.chatbot_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}/chat"
}

output "kendra_index_id" {
  description = "ID of the Kendra index"
  value       = aws_kendra_index.document_index.id
}

output "kendra_datasource_id" {
  description = "ID of the Kendra data source"
  value       = aws_kendra_data_source.s3_data_source.id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website_distribution.id
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.chatbot_lambda.function_name
}
