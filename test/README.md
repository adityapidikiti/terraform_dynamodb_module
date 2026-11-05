# Tests

Terraform test configuration for this module. Terraform 1.7 or newer is
required, because the plan tests use `mock_provider`.

`module.tf` calls the module four ways: a minimal on-demand table, a
provisioned table with autoscaling and a GSI, an on-demand table with
throughput limits and a TTL, and a `STANDARD_INFREQUENT_ACCESS` table without
PITR. `outputs.tf` exposes their results for the assertions.

Tables are created with `environment = "dev"`. That turns off deletion
protection, so the teardown at the end of a run can delete them.

## Plan tests

`plan.tftest.hcl` mocks the AWS provider. It needs no credentials and creates
nothing.

```bash
cd test
terraform init
terraform test -filter=plan.tftest.hcl
```

## Apply tests

`apply.tftest.hcl` creates real tables, checks the names, ARNs and stream
metadata, then destroys them.

```bash
cd test
terraform init
terraform test -filter=apply.tftest.hcl
```

Credentials come from the standard provider chain. An IAM role is better than
static keys:

- Assume-role profile in `~/.aws/config`, then `export AWS_PROFILE=dynamodb-test`:

  ```ini
  [profile dynamodb-test]
  role_arn       = arn:aws:iam::123456789012:role/terraform-dynamodb-test
  source_profile = default
  region         = us-east-1
  ```

- `assume_role` block in the provider in `module.tf`.
- Instance or task role attached on EC2, ECS or EKS, with nothing exported.
- Temporary credentials exported from an existing session. Include
  `AWS_SESSION_TOKEN` when they came from `sts:AssumeRole`; without it the
  provider returns `InvalidClientTokenId`.

The region is fixed at `us-east-1` in `module.tf`.

The identity needs DynamoDB access, plus `application-autoscaling` for the
autoscaled table:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:UpdateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:UpdateContinuousBackups",
        "dynamodb:TagResource",
        "dynamodb:ListTagsOfResource",
        "application-autoscaling:RegisterScalableTarget",
        "application-autoscaling:DescribeScalableTargets",
        "application-autoscaling:PutScalingPolicy",
        "application-autoscaling:DescribeScalingPolicies",
        "application-autoscaling:DeleteScalingPolicy",
        "application-autoscaling:DeregisterScalableTarget"
      ],
      "Resource": "*"
    }
  ]
}
```

In a shared account, scope `Resource` to the table ARNs. The tests create
tables named `tf-dynamodb-module-test-*`.

## CI

`.github/workflows/terraform-test.yml` runs fmt, validate and
`plan.tftest.hcl` on every push and pull request. The apply tests only run on
manual dispatch, with `run_apply_tests` ticked, because they create real
infrastructure. That job uses OIDC when the `AWS_ROLE_ARN` repository variable
is set and falls back to the access key secrets otherwise.
