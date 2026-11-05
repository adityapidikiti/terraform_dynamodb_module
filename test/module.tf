# Module calls used by the tests. The plan tests substitute a mock provider.
# Tables use environment = "dev" so deletion protection is off and the
# teardown at the end of a run succeeds.

provider "aws" {
  region = "us-east-1"
}

# Minimal on-demand table.
module "basic" {
  source = "../"

  table_name  = "tf-dynamodb-module-test-basic"
  hash_key    = "id"
  environment = "dev"

  app        = "terraform-dynamodb-module-tests"
  managed_by = "terraform-test"

  attributes = [
    {
      name = "id"
      type = "S"
    },
  ]
}

# Provisioned, autoscaled table with a GSI and a stream.
module "provisioned_autoscaling_gsi" {
  source = "../"

  table_name       = "tf-dynamodb-module-test-provisioned"
  hash_key         = "UserID"
  range_key        = "TopScore"
  stream_enabled   = "true"
  stream_view_type = "NEW_IMAGE"
  billing_mode     = "PROVISIONED"
  environment      = "dev"

  app        = "terraform-dynamodb-module-tests"
  managed_by = "terraform-test"

  attributes = [
    {
      name = "UserID"
      type = "S"
    },
    {
      name = "TopScore"
      type = "N"
    },
    {
      name = "GameTitle"
      type = "S"
    },
  ]

  enable_autoscaler            = "true"
  enable_gsi_autoscaler        = "true"
  autoscale_min_read_capacity  = 1
  autoscale_max_read_capacity  = 2
  autoscale_min_write_capacity = 1
  autoscale_max_write_capacity = 2

  global_secondary_index = [
    {
      name               = "GameTitleIndex"
      hash_key           = "GameTitle"
      range_key          = "TopScore"
      read_capacity      = 1
      write_capacity     = 1
      projection_type    = "INCLUDE"
      non_key_attributes = ["UserID"]
    },
  ]
}

# On-demand with throughput limits and a TTL.
module "ondemand_limits_ttl" {
  source = "../"

  table_name  = "tf-dynamodb-module-test-ondemand"
  hash_key    = "id"
  environment = "dev"

  app        = "terraform-dynamodb-module-tests"
  managed_by = "terraform-test"

  attributes = [
    {
      name = "id"
      type = "S"
    },
  ]

  on_demand_max_rcu = 10
  on_demand_max_wcu = 15

  ttl = [
    {
      attribute_name = "expires_at"
      enabled        = true
    },
  ]
}

# STANDARD_INFREQUENT_ACCESS without PITR.
module "standard_ia_no_pitr" {
  source = "../"

  table_name                    = "tf-dynamodb-module-test-standard-ia"
  hash_key                      = "id"
  environment                   = "dev"
  table_class                   = "STANDARD_INFREQUENT_ACCESS"
  enable_point_in_time_recovery = "false"

  app        = "terraform-dynamodb-module-tests"
  managed_by = "terraform-test"

  attributes = [
    {
      name = "id"
      type = "S"
    },
  ]
}
