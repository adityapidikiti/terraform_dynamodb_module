# terraform_dynamodb_module

Terraform module for creating AWS DynamoDB tables.

When using this module, pin `?ref=` to a tag or commit SHA in the consuming
configuration so that module upgrades are explicit.

## Quick Start

```hcl
module "dynamodb_table" {
  source = "git@github.com:adityapidikiti/terraform_dynamodb_module.git"

  table_name    = "${local.env}-my-table" # rename

  # Optional: Set maximum capacity limits for cost control
  on_demand_max_rcu = 1000  # Max read request units
  on_demand_max_wcu = 500   # Max write request units

  # Required attributes
  hash_key   = "id"
  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

  # Required tagging
  app           = "my-app"
  managed_by    = local.managed_by
  environment   = local.env
}
```

## Advanced Configuration

### Global Secondary Index (GSI)
Create additional indexes to support different query patterns beyond the primary key.

```hcl
global_secondary_index = [
  {
    name               = "my-gsi"
    hash_key           = "gsi_hash_key"
    range_key          = "gsi_range_key"
    projection_type    = "ALL"
    # For Pay-per-Request mode with limits
    on_demand_max_rcu  = 500
    on_demand_max_wcu  = 250
  }
]

```

### DynamoDB Streams
Capture changes to items in your table to trigger downstream processing or replication.

```hcl
stream_enabled   = "true"
stream_view_type = "NEW_AND_OLD_IMAGES"  # Options: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES
```

### Time to Live (TTL)
Automatically delete expired items from your table to reduce storage costs and maintain data hygiene.

```hcl
ttl = [
  {
    attribute_name = "expires_at"
    enabled        = true
  }
]
```

### Storage Class Configuration
Configure the storage class to optimize costs for infrequently accessed data.

```hcl
table_class = "STANDARD_INFREQUENT_ACCESS"  # Options: STANDARD, STANDARD_INFREQUENT_ACCESS
```

### Provisioned Capacity

⚠️ This is not recommended. Prefer Pay-per-request (default) instead, as it is more responsive (less throtlling) and cheaper.

If using provisioned capacity, autoscaling must be configured to avoid throttling and optimize costs. You also will need to monitor and tune the thresholds to ensure that we're effectively using the capacity being paid for.

```hcl
module "dynamodb_table" {
  source = "git@github.com:adityapidikiti/terraform_dynamodb_module.git"

  table_name   = "${local.env}-my-table"
  billing_mode = "PROVISIONED"

  # Auto-scaling (required for provisioned mode)
  enable_autoscaler = "true"
  autoscale_min_read_capacity  = 5
  autoscale_max_read_capacity  = 20
  autoscale_min_write_capacity = 5
  autoscale_max_write_capacity = 20
  autoscale_read_target        = 75  # Target utilization %
  autoscale_write_target       = 75  # Target utilization %

  # Required attributes
  hash_key   = "id"
  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

  # Required tagging
  app           = "my-app"
  managed_by    = local.managed_by
  environment   = local.env
}
```

If also using GSI, you'll want to enable:

```hcl
enable_gsi_autoscaler = "true"
```

### Import Table from S3
Import existing data from S3 into a new DynamoDB table during table creation.

```hcl
import_table = {
  input_format = "CSV"  # Options: DYNAMODB_JSON, CSV, ION
  bucket       = "my-import-bucket"
  key_prefix   = "data/"

  input_format_options = {
    csv = {
      delimiter   = ","
      header_list = ["id", "name", "email"]
    }
  }
}
```

## Example - More Complex

```hcl
module "user_table" {
  source = "git@github.com:adityapidikiti/terraform_dynamodb_module.git"

  table_name   = "${local.env}-users"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "user_id"
  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    }
  ]

  global_secondary_index = [
    {
      name            = "email-index"
      hash_key        = "email"
      projection_type = "ALL"
    }
  ]

  ttl = [
    {
      attribute_name = "expires_at"
      enabled        = true
    }
  ]

  # Tagging
  app           = "user-service"
  managed_by    = local.managed_by
  environment   = local.env
}
```

## Testing

The `test/` directory contains a Terraform configuration that instantiates this
module four ways, plus `*.tftest.hcl` files that exercise it with
[`terraform test`](https://developer.hashicorp.com/terraform/language/tests).
Terraform 1.7 or newer is required.

`test/module.tf` declares the module calls. Each one targets a different code
path: a minimal on-demand table, a provisioned table with autoscaling and a
GSI, an on-demand table with throughput ceilings and TTL, and a
`STANDARD_INFREQUENT_ACCESS` table with PITR disabled. `test/outputs.tf`
exposes their results so tests have something to assert against.

Every table is created with `environment = "dev"`. That makes the module turn
off deletion protection, which matters because `terraform test` destroys the
infrastructure it creates — a protected table would fail to delete.

### Plan tests (no AWS credentials)

`test/plan.tftest.hcl` starts with `mock_provider "aws" {}`. The AWS provider
therefore never contacts AWS: no account, no credentials, no resources, no
cost. These runs catch invalid arguments for the provider version in use,
missing required inputs, type errors, and broken wiring between module inputs
and outputs.

```bash
cd test
terraform init
terraform test -filter=plan.tftest.hcl
```

### Apply tests (real AWS)

`test/apply.tftest.hcl` uses `command = apply` against a real account. It
creates the tables, asserts on the returned names, ARNs, and stream metadata,
then `terraform test` destroys everything at the end of the run.

```bash
cd test
terraform init
terraform test -filter=apply.tftest.hcl
```

Credentials must be available to the AWS provider. Pick one of the methods
below. The provider block in `test/module.tf` fixes the region at `us-east-1`;
change it there if you need a different one.

The identity running these tests needs DynamoDB permissions plus, for the table
that enables autoscaling, `application-autoscaling:*` on the table and index.
A minimal policy:

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

Scope `Resource` down to the table ARNs in a shared account. Everything the
tests create is named `tf-dynamodb-module-test-*`.

#### Option 1 — IAM role via a named profile (recommended)

This is the safest local setup: you keep short-lived credentials and never put
an access key on disk. Define an assume-role profile in `~/.aws/config`:

```ini
[profile dynamodb-test]
role_arn       = arn:aws:iam::123456789012:role/terraform-dynamodb-test
source_profile = default
region         = us-east-1
```

`source_profile` is any profile that can already call `sts:AssumeRole` — your
SSO login, for example. Then point Terraform at the profile:

```bash
cd test
terraform init
export AWS_PROFILE=dynamodb-test
terraform test -filter=apply.tftest.hcl
```

The provider assumes the role and everything runs as that role. Verify which
identity you are before running, so you do not apply to the wrong account:

```bash
aws sts get-caller-identity --profile dynamodb-test
```

#### Option 2 — IAM role assumed by the provider itself

If you would rather not use a profile, declare the role in the provider block
in `test/module.tf`:

```hcl
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/terraform-dynamodb-test"
    session_name = "terraform-dynamodb-module-test"
    # Optional: MFA and external ID for stricter setups.
    # external_id = "..."
    # duration    = "1h"
  }
}
```

Terraform assumes the role for every AWS call. Leave the block in place only
while testing; it is configuration, not a secret, but it does pin the account.

#### Option 3 — IAM role from instance or task metadata

On EC2, ECS, or EKS the credentials are already there — attach the role to the
instance or task and run the tests with no AWS environment variables at all:

```bash
cd test
terraform init
terraform test -filter=apply.tftest.hcl
```

The provider discovers the instance profile or task role automatically. On EKS
with IRSA, this works through the web identity token the pod already mounts.

#### Option 4 — assume a role from the CLI session (web identity / SSO)

If you have already assumed a role in your shell, either through
`aws sso login` or by exporting a web identity token, export the resulting
credentials and run the tests:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # required for temporary credentials
export AWS_REGION=us-east-1
```

Temporary credentials from `sts:AssumeRole` always include a session token. A
missing `AWS_SESSION_TOKEN` is the usual cause of `InvalidClientTokenId` when
using role credentials.

### Continuous integration

`.github/workflows/terraform-test.yml` runs three jobs:

- **fmt + validate** — `terraform fmt -check -recursive` and `terraform validate`
on the root module, on every push and pull request.
- **terraform test (mocked AWS)** — the plan tests. No secrets are referenced,
so this job is safe to run on pull requests from forks. This is the job that
gates a merge.
- **terraform test (live AWS)** — the apply tests. Manual dispatch only, and
only when the `run_apply_tests` input is ticked, because it creates real
infrastructure. It authenticates in one of two ways: if the repository
variable `AWS_ROLE_ARN` is set it uses GitHub OIDC to assume that role (no
stored keys, nothing long-lived), otherwise it falls back to the
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` repository secrets. Set the
variable rather than the secrets where you can.

To use OIDC, create an IAM role whose trust policy allows GitHub's provider
(`token.actions.githubusercontent.com`) for this repository, then add its ARN
as a repository variable:

```bash
gh variable set AWS_ROLE_ARN \
  --body arn:aws:iam::123456789012:role/github-terraform-dynamodb-test \
  --repo adityapidikiti/terraform_dynamodb_module
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.read_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.read_policy_index](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.write_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.write_policy_index](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.read_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_appautoscaling_target.read_target_index](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_appautoscaling_target.write_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_appautoscaling_target.write_target_index](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_dynamodb_table.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [null_resource.global_secondary_index_names](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | n/a | `string` | n/a | yes |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | Key values. | `list(any)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_hash_key"></a> [hash\_key](#input\_hash\_key) | DynamoDB table Hash Key | `string` | n/a | yes |
| <a name="input_managed_by"></a> [managed\_by](#input\_managed\_by) | n/a | `string` | n/a | yes |
| <a name="input_table_name"></a> [table\_name](#input\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_autoscale_max_read_capacity"></a> [autoscale\_max\_read\_capacity](#input\_autoscale\_max\_read\_capacity) | DynamoDB autoscaling max read capacity | `number` | `20` | no |
| <a name="input_autoscale_max_read_capacity_index"></a> [autoscale\_max\_read\_capacity\_index](#input\_autoscale\_max\_read\_capacity\_index) | DynamoDB autoscaling max read capacity for index. Uses `autoscale_max_read_capacity` if not set | `any` | `null` | no |
| <a name="input_autoscale_max_write_capacity"></a> [autoscale\_max\_write\_capacity](#input\_autoscale\_max\_write\_capacity) | DynamoDB autoscaling max write capacity | `number` | `20` | no |
| <a name="input_autoscale_max_write_capacity_index"></a> [autoscale\_max\_write\_capacity\_index](#input\_autoscale\_max\_write\_capacity\_index) | DynamoDB autoscaling max write capacity for index. Uses `autoscale_max_write_capacity` if not set | `any` | `null` | no |
| <a name="input_autoscale_min_read_capacity"></a> [autoscale\_min\_read\_capacity](#input\_autoscale\_min\_read\_capacity) | DynamoDB autoscaling min read capacity | `number` | `5` | no |
| <a name="input_autoscale_min_read_capacity_index"></a> [autoscale\_min\_read\_capacity\_index](#input\_autoscale\_min\_read\_capacity\_index) | DynamoDB autoscaling min read capacity for index. Uses `autoscale_min_read_capacity` if not set | `any` | `null` | no |
| <a name="input_autoscale_min_write_capacity"></a> [autoscale\_min\_write\_capacity](#input\_autoscale\_min\_write\_capacity) | DynamoDB autoscaling min write capacity | `number` | `5` | no |
| <a name="input_autoscale_min_write_capacity_index"></a> [autoscale\_min\_write\_capacity\_index](#input\_autoscale\_min\_write\_capacity\_index) | DynamoDB autoscaling min write capacity for index. Uses `autoscale_min_write_capacity` if not set | `any` | `null` | no |
| <a name="input_autoscale_read_target"></a> [autoscale\_read\_target](#input\_autoscale\_read\_target) | The target value for DynamoDB read autoscaling | `number` | `75` | no |
| <a name="input_autoscale_write_target"></a> [autoscale\_write\_target](#input\_autoscale\_write\_target) | The target value for DynamoDB write autoscaling | `number` | `75` | no |
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | Controls how you are charged for read and write throughput and how you manage capacity. The valid values are `PROVISIONED` and `PAY_PER_REQUEST`. Defaults to `PAY_PER_REQUEST` | `string` | `"PAY_PER_REQUEST"` | no |
| <a name="input_enable_autoscaler"></a> [enable\_autoscaler](#input\_enable\_autoscaler) | Flag to enable/disable DynamoDB autoscaling | `string` | `"false"` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Defaults to false in dev and true in stage and prod | `bool` | `null` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Enable DynamoDB server-side encryption | `string` | `"true"` | no |
| <a name="input_enable_gsi_autoscaler"></a> [enable\_gsi\_autoscaler](#input\_enable\_gsi\_autoscaler) | Flag to enable/disable autoscaling on Global Secondary Indexes (GSI) with the same settings as the table | `string` | `"false"` | no |
| <a name="input_enable_point_in_time_recovery"></a> [enable\_point\_in\_time\_recovery](#input\_enable\_point\_in\_time\_recovery) | Flag to enable/disable the Point in Time Recovery (PITR) backup mechanism | `string` | `"true"` | no |
| <a name="input_global_secondary_index"></a> [global\_secondary\_index](#input\_global\_secondary\_index) | https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SQLtoNoSQL.Indexes.html | `any` | `[]` | no |
| <a name="input_import_table"></a> [import\_table](#input\_import\_table) | Configurations for importing data into a new table from s3 <br/>    https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table#import_table | `any` | `{}` | no |
| <a name="input_local_secondary_index"></a> [local\_secondary\_index](#input\_local\_secondary\_index) | https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SQLtoNoSQL.Indexes.html | `any` | `[]` | no |
| <a name="input_on_demand_max_rcu"></a> [on\_demand\_max\_rcu](#input\_on\_demand\_max\_rcu) | Maximum number of read request units for the specified table. To specify set the value greater than or equal to 1. To remove set the value to -1. | `number` | `null` | no |
| <a name="input_on_demand_max_wcu"></a> [on\_demand\_max\_wcu](#input\_on\_demand\_max\_wcu) | Maximum number of write request units for the specified table. To specify set the value greater than or equal to 1. To remove set the value to -1. | `number` | `null` | no |
| <a name="input_range_key"></a> [range\_key](#input\_range\_key) | DynamoDB table Range Key | `string` | `""` | no |
| <a name="input_static_read_capacity"></a> [static\_read\_capacity](#input\_static\_read\_capacity) | Table read capacity when not using autoscaling  (enable\_autoscaler is false). | `number` | `1` | no |
| <a name="input_static_write_capacity"></a> [static\_write\_capacity](#input\_static\_write\_capacity) | Table write capacity when not using autoscaling (enable\_autoscaler is false). | `number` | `1` | no |
| <a name="input_stream_enabled"></a> [stream\_enabled](#input\_stream\_enabled) | Flag to enable/disable DynamoDB Stream | `string` | `"false"` | no |
| <a name="input_stream_view_type"></a> [stream\_view\_type](#input\_stream\_view\_type) | When stream is enabled and an item in the table is modified, stream\_view\_type determines what information is written to the table's stream. Valid values are `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES` | `string` | `""` | no |
| <a name="input_table_class"></a> [table\_class](#input\_table\_class) | The storage class of the dynamodb table. Valid values are `STANDARD` and `STANDARD_INFREQUENT_ACCESS`. Defaults to `STANDARD` | `string` | `"STANDARD"` | no |
| <a name="input_testing"></a> [testing](#input\_testing) | Whether or not resources will be created with a unique ID so that they're easier to test. | `string` | `"false"` | no |
| <a name="input_ttl"></a> [ttl](#input\_ttl) | TTL attribute for a dynamodb table. | `list(any)` | `[]` | no |
| <a name="input_warm_throughput_read_units"></a> [warm\_throughput\_read\_units](#input\_warm\_throughput\_read\_units) | Number of read units per second for warm throughput. Minimum value is 12000. | `number` | `null` | no |
| <a name="input_warm_throughput_write_units"></a> [warm\_throughput\_write\_units](#input\_warm\_throughput\_write\_units) | Number of write units per second for warm throughput. Minimum value is 4000. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_table_arn"></a> [table\_arn](#output\_table\_arn) | Table ARN. |
| <a name="output_table_id"></a> [table\_id](#output\_table\_id) | Table ID. |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | Table name. |
| <a name="output_table_stream_arn"></a> [table\_stream\_arn](#output\_table\_stream\_arn) | The ARN of the Table Stream. Only available when stream is enabled |
| <a name="output_table_stream_label"></a> [table\_stream\_label](#output\_table\_stream\_label) | Table Stream Label. A timestamp, in ISO 8601 format, for stream. The combination of AWS customer ID, table name and this field is guaranteed to be unique, and can be used for creating CloudWatch alarms. Only available when stream is enabled |
