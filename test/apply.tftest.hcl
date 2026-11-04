# Apply tests against real AWS. These create DynamoDB tables, verify them, and
# destroy them again (terraform test tears down the infrastructure at the end of
# each run).
#
#   cd test
#   terraform init
#   terraform test -filter=apply.tftest.hcl
#
# Requires working AWS credentials, for example:
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
#   export AWS_REGION=us-east-1
#
# Not run in CI by default: the workflow filters to plan.tftest.hcl. Point it at
# this file (and configure credentials) if you want live coverage.
#
# Every table uses environment = "dev" so deletion protection stays off and the
# teardown succeeds.

run "create_and_verify_tables" {
  command = apply

  assert {
    condition     = output.basic.name == "tf-dynamodb-module-test-basic"
    error_message = "The created table is not named as requested."
  }

  assert {
    condition     = can(regex("^arn:aws:dynamodb:", output.basic.arn))
    error_message = "table_arn is not a DynamoDB ARN: got ${output.basic.arn}."
  }

  assert {
    condition     = output.basic.id == output.basic.name
    error_message = "table_id should equal the table name for DynamoDB."
  }

  assert {
    condition     = can(regex("^arn:aws:dynamodb:", output.provisioned_autoscaling_gsi.stream_arn))
    error_message = "A table created with stream_enabled = \"true\" should expose a stream ARN."
  }

  assert {
    condition     = output.provisioned_autoscaling_gsi.stream_label != ""
    error_message = "A stream-enabled table should expose a stream label."
  }

  assert {
    condition     = output.provisioned_autoscaling_gsi.name == "tf-dynamodb-module-test-provisioned"
    error_message = "The provisioned table is not named as requested."
  }

  assert {
    condition     = output.ondemand_limits_ttl.name == "tf-dynamodb-module-test-ondemand"
    error_message = "The on-demand table is not named as requested."
  }

  assert {
    condition     = output.standard_ia_no_pitr.name == "tf-dynamodb-module-test-standard-ia"
    error_message = "The STANDARD_INFREQUENT_ACCESS table is not named as requested."
  }
}
