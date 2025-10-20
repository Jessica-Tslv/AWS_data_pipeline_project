resource "aws_athena_workgroup" "data_pipeline" {
  name = "data-pipeline-workgroup"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_bucket.bucket}/athena-queries/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  description = "Athena workgroup for queries saving results to S3"
}
