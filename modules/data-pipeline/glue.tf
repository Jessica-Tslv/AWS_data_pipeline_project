# IAM role that Glue will assume
resource "aws_iam_role" "glue_role" {
  name = "glue-data-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Least-privilege IAM policy for Glue Crawler
resource "aws_iam_policy" "glue_least_privilege" {
  name        = "glue-crawler-least-privilege"
  description = "Minimum permissions for AWS Glue Crawler to read processed data and update the catalog"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 access - read processed data only
      {
        Sid    = "S3ReadAccess",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/processed-data/*"
        ]
      },

      # Glue Catalog access - allow crawler to manage tables in the specified DB
      {
        Sid    = "GlueCatalogAccess",
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetCrawler",
          "glue:UpdateCrawler",
          "glue:StartCrawler",
          "glue:GetCrawlerMetrics"
        ],
        Resource = "*"
      },

      # CloudWatch Logs for crawler logging
      {
        Sid    = "CloudWatchLogs",
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "glue_policy_attachment" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_least_privilege.arn
}

# Glue Catalog database to store metadata
resource "aws_glue_catalog_database" "data_db" {
  name = "data_pipeline_db"
}

# Glue crawler to discover Parquet data under /processed-data/
resource "aws_glue_crawler" "processed_data_crawler" {
  name          = "processed-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.data_db.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/processed-data/"
  }

  # optional: run at 12:00 midday 20.09
  schedule = "cron(0 12 20 9 ? *)"

  # optional: custom configuration
  configuration = jsonencode({
    Version = 1.0,
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  tags = {
    Environment = var.environment
    ServiceName = var.service_name
  }
}
