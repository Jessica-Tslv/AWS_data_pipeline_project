resource "aws_sns_topic" "data_topic" {
  name = "data-topic"
}

resource "aws_sns_topic_subscription" "queue_subscription" {
  topic_arn = aws_sns_topic.data_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.data_queue.arn
}

resource "aws_sns_topic_policy" "allow_s3_publish" {
  arn = aws_sns_topic.data_topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      },
      Action = "SNS:Publish",
      Resource = aws_sns_topic.data_topic.arn,
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.data_bucket.arn
        }
      }
    }]
  })
}