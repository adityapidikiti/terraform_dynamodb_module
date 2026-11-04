# Credential-free tests. The AWS provider is mocked, so nothing is created in
# a real account and no AWS credentials are required.
#
#   cd test
#   terraform init
#   terraform test -filter=plan.tftest.hcl
#
# These catch the failures that matter most in review: invalid arguments for
# the provider version in use, missing required inputs, type errors, and
# wiring mistakes between the module's variables and outputs.

mock_provider "aws" {}

run "basic_table_plans" {
  command = plan

  assert {
    condition     = output.basic.name == "tf-dynamodb-module-test-basic"
    error_message = "The module did not propagate table_name to the DynamoDB table."
  }
}

run "provisioned_autoscaling_gsi_plans" {
  command = plan

  assert {
    condition     = output.provisioned_autoscaling_gsi.name == "tf-dynamodb-module-test-provisioned"
    error_message = "The provisioned table did not receive the expected table_name."
  }
}

run "ondemand_limits_ttl_plans" {
  command = plan

  assert {
    condition     = output.ondemand_limits_ttl.name == "tf-dynamodb-module-test-ondemand"
    error_message = "The on-demand table did not receive the expected table_name."
  }
}

run "standard_ia_no_pitr_plans" {
  command = plan

  assert {
    condition     = output.standard_ia_no_pitr.name == "tf-dynamodb-module-test-standard-ia"
    error_message = "The STANDARD_INFREQUENT_ACCESS table did not receive the expected table_name."
  }
}
