# Runs against a real AWS account and destroys the tables afterwards.
# Credentials and permissions are covered in test/README.md.
#   terraform test -filter=apply.tftest.hcl

run "create_tables" {
  command = apply

  assert {
    condition     = output.basic.name == "tf-dynamodb-module-test-basic"
    error_message = "Unexpected table name."
  }

  assert {
    condition     = can(regex("^arn:aws:dynamodb:", output.basic.arn))
    error_message = "table_arn is not a DynamoDB ARN: ${output.basic.arn}."
  }

  assert {
    condition     = output.basic.id == output.basic.name
    error_message = "table_id should match the table name."
  }

  assert {
    condition     = can(regex("^arn:aws:dynamodb:", output.provisioned_autoscaling_gsi.stream_arn))
    error_message = "stream_enabled = \"true\" did not produce a stream ARN."
  }

  assert {
    condition     = output.provisioned_autoscaling_gsi.stream_label != ""
    error_message = "Stream-enabled table has no stream label."
  }

  assert {
    condition     = output.provisioned_autoscaling_gsi.name == "tf-dynamodb-module-test-provisioned"
    error_message = "Unexpected provisioned table name."
  }

  assert {
    condition     = output.ondemand_limits_ttl.name == "tf-dynamodb-module-test-ondemand"
    error_message = "Unexpected on-demand table name."
  }

  assert {
    condition     = output.standard_ia_no_pitr.name == "tf-dynamodb-module-test-standard-ia"
    error_message = "Unexpected STANDARD_INFREQUENT_ACCESS table name."
  }
}
