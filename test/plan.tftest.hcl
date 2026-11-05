# Provider is mocked, so this needs no AWS credentials and creates nothing.
#   terraform test -filter=plan.tftest.hcl

mock_provider "aws" {}

run "basic" {
  command = plan

  assert {
    condition     = output.basic.name == "tf-dynamodb-module-test-basic"
    error_message = "table_name was not passed through to the table."
  }
}

run "provisioned" {
  command = plan

  assert {
    condition     = output.provisioned_autoscaling_gsi.name == "tf-dynamodb-module-test-provisioned"
    error_message = "table_name was not passed through to the provisioned table."
  }
}

run "ondemand" {
  command = plan

  assert {
    condition     = output.ondemand_limits_ttl.name == "tf-dynamodb-module-test-ondemand"
    error_message = "table_name was not passed through to the on-demand table."
  }
}

run "standard_ia" {
  command = plan

  assert {
    condition     = output.standard_ia_no_pitr.name == "tf-dynamodb-module-test-standard-ia"
    error_message = "table_name was not passed through to the STANDARD_INFREQUENT_ACCESS table."
  }
}
