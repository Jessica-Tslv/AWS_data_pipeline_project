# Rule that monitors the data bucket's raw-data prefix and checks when object is uploaded
# EventBridge rule for S3 object creation in /raw-data/
# EventBridge can listen to S3 ObjectCreated events with a prefix filter.
resource "aws_cloudwatch_event_rule" "s3_put_rule" {
  name        = "s3-raw-data-upload"
  description = "Triggered when object is uploaded to /raw-data/ prefix"
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : [aws_s3_bucket.data_bucket.bucket],
      "object" : {
        "key" : [{
          "prefix" : "raw-data/"
        }]
      }
    }
  })
}

# This resource is waiting for object to be uploaded to /raw-data/ prefix to
# notify SNS topic
resource "aws_cloudwatch_event_target" "send_to_sns" {
  rule      = aws_cloudwatch_event_rule.s3_put_rule.name
  arn       = aws_sns_topic.data_topic.arn
}

# Creation of a SNS role
resource "aws_iam_role" "eventbridge_role" {
  name = "eventbridge-sns-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Granting access to the SNS role
resource "aws_iam_role_policy" "eventbridge_policy" {
  role = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = aws_sns_topic.data_topic.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule      = aws_cloudwatch_event_rule.s3_put_rule.name
  arn       = aws_sns_topic.data_topic.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
}

# Create CloudWatch Log Group to monitor the logs for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.csv_to_parquet.function_name}"
  retention_in_days = 7
}
