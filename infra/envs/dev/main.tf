locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -------------------------
# S3 Buckets (Bronze/Silver)
# -------------------------

resource "aws_s3_bucket" "bronze" {
  bucket        = "${local.name_prefix}-bronze"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket" "silver" {
  bucket        = "${local.name_prefix}-silver"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "bronze" {
  bucket                  = aws_s3_bucket.bronze.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "silver" {
  bucket                  = aws_s3_bucket.silver.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "silver" {
  bucket = aws_s3_bucket.silver.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  rule {
    id     = "expire-bronze-objects"
    status = "Enabled"
    expiration { days = 30 }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "silver" {
  bucket = aws_s3_bucket.silver.id
  rule {
    id     = "expire-silver-objects"
    status = "Enabled"
    expiration { days = 90 }
  }
}

# -------------------------
# DynamoDB (metadata table)
# -------------------------
resource "aws_dynamodb_table" "events" {
  name         = "${local.name_prefix}-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.tags
}

# -------------------------
# SQS + DLQ
# -------------------------
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-dlq"
  message_retention_seconds = 1209600
  tags                      = local.tags
}

resource "aws_sqs_queue" "queue" {
  name                       = "${local.name_prefix}-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = local.tags
}

# -------------------------
# API Lambda (deploy from services/api/dist)
# -------------------------

data "archive_file" "api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../services/api/dist"
  output_path = "${path.module}/.build/api.zip"
}

resource "aws_iam_role" "api_lambda_role" {
  name = "${local.name_prefix}-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Least privilege policy: write to S3 bronze, write to DDB, send to SQS, write logs
resource "aws_iam_policy" "api_lambda_policy" {
  name = "${local.name_prefix}-api-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      # S3 put object into bronze bucket
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.bronze.arn}/*"
      },
      # DynamoDB put item into events table
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.events.arn
      },
      # SQS send message to queue
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = aws_sqs_queue.queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_attach_policy" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = aws_iam_policy.api_lambda_policy.arn
}

resource "aws_lambda_function" "api" {
  function_name = "${local.name_prefix}-api"
  role          = aws_iam_role.api_lambda_role.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.api_zip.output_path
  source_code_hash = data.archive_file.api_zip.output_base64sha256

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      BRONZE_BUCKET = aws_s3_bucket.bronze.bucket
      EVENTS_TABLE  = aws_dynamodb_table.events.name
      QUEUE_URL     = aws_sqs_queue.queue.url
    }
  }

  tags = local.tags
}
data "archive_file" "worker_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../services/worker/dist"
  output_path = "${path.module}/.build/worker.zip"
}
resource "aws_iam_role" "worker_lambda_role" {
  name = "${local.name_prefix}-worker-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_policy" "worker_lambda_policy" {
  name = "${local.name_prefix}-worker-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Logs
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      # Read from Bronze
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.bronze.arn}/*"
      },
      # Write to Silver
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.silver.arn}/*"
      },
      # Update DynamoDB
      {
        Effect   = "Allow",
        Action   = ["dynamodb:UpdateItem"],
        Resource = aws_dynamodb_table.events.arn
      },
      # EventBridge publish
      {
        Effect   = "Allow",
        Action   = ["events:PutEvents"],
        Resource = "*"
      },
      # SQS consume (needed for event source mapping)
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = aws_sqs_queue.queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_attach_policy" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = aws_iam_policy.worker_lambda_policy.arn
}
resource "aws_lambda_function" "worker" {
  function_name = "${local.name_prefix}-worker"
  role          = aws_iam_role.worker_lambda_role.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.worker_zip.output_path
  source_code_hash = data.archive_file.worker_zip.output_base64sha256

  timeout     = 20
  memory_size = 256

  environment {
    variables = {
      SILVER_BUCKET  = aws_s3_bucket.silver.bucket
      EVENTS_TABLE   = aws_dynamodb_table.events.name
      EVENT_BUS_NAME = "default"
    }
  }

  tags = local.tags
}
resource "aws_lambda_event_source_mapping" "worker_from_sqs" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.worker.arn

  batch_size                         = 5
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.name_prefix}-http-api"
  protocol_type = "HTTP"
  tags          = local.tags
}
resource "aws_apigatewayv2_integration" "api_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "post_events" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /events"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda_integration.id}"
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}
resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
