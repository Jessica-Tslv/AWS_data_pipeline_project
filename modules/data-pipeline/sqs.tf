# Create SQS queue
resource "aws_sqs_queue" "data_queue" {
  name                       = "data-queue"
  visibility_timeout_seconds = 310  # must be bigger than the lambda timeout
}

# Allow SNS to send messages to SQS
resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.data_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSNSToSendMessages"
        Effect    = "Allow"
        Principal = "*"
        Action    = "SQS:SendMessage"
        Resource  = aws_sqs_queue.data_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.data_topic.arn
          }
        }
      },
      {
        Sid       = "AllowLambdaToPollMessages"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "SQS:ReceiveMessage",
          "SQS:DeleteMessage",
          "SQS:GetQueueAttributes",
          "SQS:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.data_queue.arn
      }
    ]
  })
}
