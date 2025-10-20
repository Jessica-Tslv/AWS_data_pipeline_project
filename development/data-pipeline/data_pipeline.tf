module "data_pipeline" {
  source = "../../modules/data-pipeline"

  environment  = var.environment
  service_name = var.service_name
  aws_region   = var.aws_region
}
