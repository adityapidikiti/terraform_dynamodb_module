variable "table_name" {
  type = string
}

variable "billing_mode" {
  description = "Controls how you are charged for read and write throughput and how you manage capacity. The valid values are `PROVISIONED` and `PAY_PER_REQUEST`. Defaults to `PAY_PER_REQUEST`"
  default     = "PAY_PER_REQUEST"
}

variable "static_write_capacity" {
  description = "Table write capacity when not using autoscaling (enable_autoscaler is false)."
  default     = 1
}

variable "static_read_capacity" {
  description = "Table read capacity when not using autoscaling  (enable_autoscaler is false)."
  default     = 1
}

variable "table_class" {
  description = "The storage class of the dynamodb table. Valid values are `STANDARD` and `STANDARD_INFREQUENT_ACCESS`. Defaults to `STANDARD`"
  default     = "STANDARD"
}

variable "ttl" {
  type        = list(any)
  description = "TTL attribute for a dynamodb table."
  default     = []
}

variable "testing" {
  description = "Whether or not resources will be created with a unique ID so that they're easier to test."
  type        = string
  default     = "false"
}

variable "attributes" {
  type        = list(any)
  description = "Key values."
}

variable "app" {
  type = string
}

variable "managed_by" {
  type = string
}

variable "environment" {
  type = string
}

variable "global_secondary_index" {
  type        = any
  description = "https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SQLtoNoSQL.Indexes.html"
  default     = []
}

variable "local_secondary_index" {
  type        = any
  description = "https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SQLtoNoSQL.Indexes.html"
  default     = []
}

variable "autoscale_write_target" {
  default     = 75
  description = "The target value for DynamoDB write autoscaling"
}

variable "autoscale_read_target" {
  default     = 75
  description = "The target value for DynamoDB read autoscaling"
}

variable "autoscale_min_read_capacity" {
  default     = 5
  description = "DynamoDB autoscaling min read capacity"
}

variable "autoscale_max_read_capacity" {
  default     = 20
  description = "DynamoDB autoscaling max read capacity"
}

variable "autoscale_min_read_capacity_index" {
  default     = null
  description = "DynamoDB autoscaling min read capacity for index. Uses `autoscale_min_read_capacity` if not set"
}

variable "autoscale_max_read_capacity_index" {
  default     = null
  description = "DynamoDB autoscaling max read capacity for index. Uses `autoscale_max_read_capacity` if not set"
}

variable "autoscale_min_write_capacity" {
  default     = 5
  description = "DynamoDB autoscaling min write capacity"
}

variable "autoscale_max_write_capacity" {
  default     = 20
  description = "DynamoDB autoscaling max write capacity"
}

variable "autoscale_min_write_capacity_index" {
  default     = null
  description = "DynamoDB autoscaling min write capacity for index. Uses `autoscale_min_write_capacity` if not set"
}

variable "autoscale_max_write_capacity_index" {
  default     = null
  description = "DynamoDB autoscaling max write capacity for index. Uses `autoscale_max_write_capacity` if not set"
}

variable "enable_encryption" {
  type        = string
  default     = "true"
  description = "Enable DynamoDB server-side encryption"
}

variable "hash_key" {
  type        = string
  description = "DynamoDB table Hash Key"
}

variable "range_key" {
  type        = string
  default     = ""
  description = "DynamoDB table Range Key"
}

variable "stream_enabled" {
  type        = string
  default     = "false"
  description = "Flag to enable/disable DynamoDB Stream"
}

variable "stream_view_type" {
  type        = string
  default     = ""
  description = "When stream is enabled and an item in the table is modified, stream_view_type determines what information is written to the table's stream. Valid values are `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES`"
}

variable "enable_autoscaler" {
  type        = string
  default     = "false"
  description = "Flag to enable/disable DynamoDB autoscaling"
}

variable "enable_point_in_time_recovery" {
  type        = string
  default     = "true"
  description = "Flag to enable/disable the Point in Time Recovery (PITR) backup mechanism"
}

variable "enable_gsi_autoscaler" {
  type        = string
  default     = "false"
  description = "Flag to enable/disable autoscaling on Global Secondary Indexes (GSI) with the same settings as the table"
}

variable "enable_deletion_protection" {
  description = "Defaults to false in dev and true in stage and prod"
  type        = bool
  default     = null
}
variable "import_table" {
  description = <<EOF
    Configurations for importing data into a new table from s3 
    https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table#import_table
  EOF
  type        = any
  default     = {}
}

variable "on_demand_max_rcu" {
  description = "Maximum number of read request units for the specified table. To specify set the value greater than or equal to 1. To remove set the value to -1."
  type        = number
  default     = null
}

variable "on_demand_max_wcu" {
  description = "Maximum number of write request units for the specified table. To specify set the value greater than or equal to 1. To remove set the value to -1."
  type        = number
  default     = null
}

variable "warm_throughput_read_units" {
  description = "Number of read units per second for warm throughput. Minimum value is 12000."
  type        = number
  default     = null
}

variable "warm_throughput_write_units" {
  description = "Number of write units per second for warm throughput. Minimum value is 4000."
  type        = number
  default     = null
}
