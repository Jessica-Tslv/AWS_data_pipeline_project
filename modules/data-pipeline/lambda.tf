data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "${path.module}/lambda_function_payload.zip"
}

# AWS lambda creation
resource "aws_lambda_function" "csv_to_parquet" {
  function_name = "csv-to-parquet"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  # Using AWS managed pandas pyarrow lambda layer that has the python packages installed
  # https://serverlessrepo.aws.amazon.com/applications/us-east-1/336392948345/aws-sdk-pandas-layer-py3-12
  layers = ["arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python312:1"]
  
  tags = {
    Environment = var.environment
    ServiceName = var.service_name
  }
}

# Create role for the lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-data-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach AWS managed policy that grants least privilegde access to lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-s3-sqs-access"
  description = "Allow Lambda to read/write S3 bucket objects and poll SQS messages"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # --- S3 permissions ---
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.data_bucket.arn}/*"
      },

      # --- SQS permissions ---
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.data_queue.arn
      }
    ]
  })
}

# Attach the managed policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "lambda_sqs" {
  event_source_arn = aws_sqs_queue.data_queue.arn
  function_name    = aws_lambda_function.csv_to_parquet.arn
  batch_size       = 1
}
