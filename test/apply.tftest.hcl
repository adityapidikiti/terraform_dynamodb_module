# Apply tests against real AWS. These create DynamoDB tables, verify them, and
# destroy them again (terraform test tears down the infrastructure at the end of
# each run).
#
#   cd test
#   terraform init
#   terraform test -filter=apply.tftest.hcl
#
# The identity needs DynamoDB plus application-autoscaling permissions; see the
# Testing section of the README for a minimal policy.
#
# Authentication — use an IAM role where you can:
#
#   1. Assume-role profile (recommended). Add to ~/.aws/config:
#        [profile dynamodb-test]
#        role_arn       = arn:aws:iam::123456789012:role/terraform-dynamodb-test
#        source_profile = default
#      then: export AWS_PROFILE=dynamodb-test
#
#   2. Provider-level assume_role — add an `assume_role` block to the provider
#      in test/module.tf.
#
#   3. Instance or task role — on EC2/ECS/EKS, attach the role and export
#      nothing.
#
#   4. Temporary credentials from a shell session:
#        export AWS_ACCESS_KEY_ID=...
#        export AWS_SECRET_ACCESS_KEY=...
#        export AWS_SESSION_TOKEN=...   # required for role credentials
#
# Static long-lived access keys also work but are the least preferred option.
#
# Not run in CI by default: the workflow filters to plan.tftest.hcl. Point it at
# this file (and configure credentials or OIDC) if you want live coverage.
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
