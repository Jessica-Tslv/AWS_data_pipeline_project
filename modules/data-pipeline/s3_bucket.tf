# Create the S3 bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "jess-data-pipeline-bucket"
  
  tags = {
    Environment = var.environment
    ServiceName = var.service_name
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create folder-like prefixes (they don't physically exist until files are uploaded)
resource "aws_s3_object" "raw_data_prefix" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "raw-data/"
}

resource "aws_s3_object" "processed_data_prefix" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "processed-data/"
}

resource "aws_s3_object" "athena_queries_prefix" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "athena-queries/"
}

resource "aws_s3_bucket_notification" "notify_sns" {
  bucket = aws_s3_bucket.data_bucket.id

  topic {
    topic_arn = aws_sns_topic.data_topic.arn
    events    = ["s3:ObjectCreated:*"]
    filter_prefix = "raw-data/" # only notify for raw-data uploads
  }
}