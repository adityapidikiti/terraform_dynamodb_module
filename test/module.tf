# Module instantiations exercised by the tests in this directory.
#
# The provider below is used by the apply tests (test/apply.tftest.hcl), which
# talk to real AWS. The plan tests (test/plan.tftest.hcl) replace it with a
# mocked provider, so they need no credentials.
#
# Every table uses environment = "dev" so the module disables deletion
# protection; terraform test destroys the infrastructure after each run, and a
# protected table would fail to delete.

provider "aws" {
  region = "us-east-1"
}

# Smallest possible table: on-demand billing, single hash key.
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

# Provisioned capacity with autoscaling on both the table and a GSI, plus a
# stream. Covers the capacity branches and the null_resource that tracks index
# names.
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

# On-demand billing with explicit throughput ceilings and a TTL attribute.
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

# Storage class plus point-in-time recovery toggled off.
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
