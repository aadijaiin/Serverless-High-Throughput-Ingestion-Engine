provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

module "messaging" {
  source      = "../../modules/messaging"
  environment = var.environment
  tags        = var.tags
}

module "storage" {
  source      = "../../modules/storage"
  environment = var.environment
  table_name  = var.table_name
  tags        = var.tags
}

module "compute" {
  source                      = "../../modules/compute"
  environment                 = var.environment
  aggregator_source_dir       = "${path.module}/../../../src/backend/aggregator"
  results_source_dir          = "${path.module}/../../../src/backend/results"
  dynamodb_table_name         = module.storage.table_name
  dynamodb_table_arn          = module.storage.table_arn
  sqs_queue_arn               = module.messaging.queue_arn
  sqs_batch_size              = var.sqs_batch_size
  sqs_batching_window_seconds = var.sqs_batching_window_seconds
  tags                        = var.tags
}

module "networking" {
  source                    = "../../modules/networking"
  environment               = var.environment
  sqs_queue_arn             = module.messaging.queue_arn
  sqs_queue_url             = module.messaging.queue_url
  results_lambda_name       = module.compute.results_lambda_name
  results_lambda_invoke_arn = module.compute.results_lambda_invoke_arn
  tags                      = var.tags
}

module "load_generator" {
  source         = "../../modules/load_generator"
  environment    = var.environment
  instance_count = var.load_generator_count
  vote_endpoint  = module.networking.vote_endpoint
  tags           = var.tags
}
