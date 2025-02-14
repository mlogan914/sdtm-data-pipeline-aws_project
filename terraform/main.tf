# =============================================================
# Root Module Configuration
# Configures resources and inputs for the SDTM data pipeline.
# =============================================================
#---------------------------------------------------------------
# S3 Module: 
# Handles S3 buckets for raw data and scripts storage
#---------------------------------------------------------------
module "s3" {
  source                             = "./s3"
  region                             = var.region
  raw_bucket_name                    = "raw-prd-5201201"
  scripts_bucket_name                = "scripts-5201201"
  oper_bucket_name                   = "oper-5201201"
  audit_bucket_name                  = "audit-5201201"
  output_bucket_name                 = "output-5201201"
  appdata_bucket_name                = "appdata-5201201"
  s3_access_point_name               = "s3-access-point-5201201"
  s3_object_lambda_access_point_name = "s3-object-lambda-access-point-5201201"
  s3_object_lambda_access_point_arn  = "arn:aws:lambda:us-west-2:525425830681:function:serverlessrepo-ComprehendPiiR-PiiRedactionFunction-0JkwowHd0ZnO"

  tags = {
    "Project"     = "SDTM-52012-01"
    "Description" = "SDTM Data Pipeline with CI/CD Integration"
  }

  # Inputs from Lambda Module
  lambda_function_name = module.lambda.process_raw_data_function_name
  lambda_function_arn  = module.lambda.process_raw_data_arn

  # Inputs from ECS Module
  ecs_task_execution_role_arn = module.ecs.ecs_task_execution_role_arn
}

#---------------------------------------------------------------
# Lambda Module: 
# Handles the Lambda functions for processing raw data
#---------------------------------------------------------------
module "lambda" {
  source = "./lambda"
}

# Glue Module: Manages AWS Glue resources (crawlers and jobs)
module "glue" {
  source = "./glue"

  # Inputs from the S3 module
  raw_bucket_name     = module.s3.raw_bucket_name
  scripts_bucket_name = module.s3.scripts_bucket_name
  raw_bucket_arn      = module.s3.raw_bucket_arn
  scripts_bucket_arn  = module.s3.scripts_bucket_arn
}

#---------------------------------------------------------------
# Step Functions Module: 
# Coordinates the data pipeline workflow
#---------------------------------------------------------------
module "step_functions" {
  source = "./step_functions"

  # Inputs from Lambda Module
  lambda_function_arn = module.lambda.process_raw_data_arn

  # Inputs from the Glue module
  glue_crawler_arn = module.glue.glue_crawler_arn
  glue_job_arn     = module.glue.glue_job_arn

  # Inputs from SNS
  sns_topic_arn = module.sns.sns_topic_arn

  # Inputs form ECS
  ecs_task_transform_arn      = module.ecs.ecs_task_transform_arn
  ecs_task_validate_arn       = module.ecs.ecs_task_validate_arn
  ecs_task_execution_role_arn = module.ecs.ecs_task_execution_role_arn
  ecs_cluster_arn             = module.ecs.ecs_cluster_arn

  # Inputs from VPC
  private_subnets = join(",", [for subnet in module.vpc.private_subnets : "\"${subnet}\""])
  public_subnets  = join(",", [for subnet in module.vpc.public_subnets : "\"${subnet}\""])
  ecs_sg_id       = module.ecs.ecs_sg_id
}

#---------------------------------------------------------------
# SNS Module: 
# Manages SNS for notifications
#---------------------------------------------------------------
module "sns" {
  source = "./sns"
}

module "vpc" {
  source = "./vpc"
}

#---------------------------------------------------------------
# ECS Module: 
# Orchestrates containers for main data processing
#---------------------------------------------------------------
module "ecs" {
  source            = "./ecs"
  region            = var.region
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  oper_bucket_arn   = module.s3.oper_bucket_arn
  audit_bucket_arn  = module.s3.audit_bucket_arn
  output_bucket_arn = module.s3.output_bucket_arn
}

