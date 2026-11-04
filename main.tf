locals {
  table_name       = var.table_name
  dynamodb_indexes = null_resource.global_secondary_index_names.*.triggers.name

  deletion_protection = var.enable_deletion_protection != null ? var.enable_deletion_protection : var.environment == "dev" ? false : true

  table_tags = {
    Name    = local.table_name
    Testing = var.testing
  }

  tagging_standard_tags = {
    App         = var.app
    ManagedBy   = var.managed_by
    Environment = var.environment
    Provisioner = "Terraform"
  }
}

resource "null_resource" "global_secondary_index_names" {
  count = length(var.global_secondary_index)
  triggers = {
    "name" = var.global_secondary_index[count.index]["name"]
  }
}

resource "aws_dynamodb_table" "default" {
  name             = local.table_name
  billing_mode     = var.billing_mode
  read_capacity    = var.billing_mode == "PAY_PER_REQUEST" ? null : (var.enable_autoscaler == "true" ? var.autoscale_min_read_capacity : var.static_read_capacity)
  write_capacity   = var.billing_mode == "PAY_PER_REQUEST" ? null : (var.enable_autoscaler == "true" ? var.autoscale_min_write_capacity : var.static_write_capacity)
  hash_key         = var.hash_key
  range_key        = var.range_key
  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_view_type
  table_class      = var.table_class

  server_side_encryption {
    enabled = var.enable_encryption
  }

  deletion_protection_enabled = local.deletion_protection

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }
  dynamic "import_table" {
    for_each = length(var.import_table) > 0 ? [var.import_table] : []
    content {
      input_format           = import_table.value.input_format                      # DYNANODB_JSON, CSV, ION
      input_compression_type = try(import_table.value.input_compression_type, null) # GZIP, ZSTD, NONE

      dynamic "input_format_options" {
        for_each = try([import_table.value.input_format_options], [])

        content {

          dynamic "csv" {
            for_each = try([input_format_options.value.csv], [])

            content {
              delimiter   = try(csv.value.delimiter, null)
              header_list = try(csv.value.header_list, null)
            }
          }
        }
      }

      s3_bucket_source {
        bucket       = import_table.value.bucket
        bucket_owner = try(import_table.value.bucket_owner, null)
        key_prefix   = try(import_table.value.key_prefix, null)
      }
    }

  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_index
    content {
      hash_key           = global_secondary_index.value.hash_key
      name               = global_secondary_index.value.name
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
      projection_type    = global_secondary_index.value.projection_type
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      read_capacity      = lookup(global_secondary_index.value, "read_capacity", null)
      write_capacity     = lookup(global_secondary_index.value, "write_capacity", null)

      # On-Demand (PAY_PER_REQUEST) tables can optionally have a max WCU/RCU per GSI
      dynamic "on_demand_throughput" {
        # if using On Demand (PAY_PER_REQUEST) and max_rcu or max_wcu is set, then create the on_demand_throughput block
        # to avoid unnecessary changes in the Plan
        for_each = var.billing_mode == "PAY_PER_REQUEST" && (contains(keys(global_secondary_index.value), "on_demand_max_rcu") || contains(keys(global_secondary_index.value), "on_demand_max_wcu")) ? [1] : []
        content {
          max_read_request_units  = lookup(global_secondary_index.value, "on_demand_max_rcu", null)
          max_write_request_units = lookup(global_secondary_index.value, "on_demand_max_wcu", null)
        }
      }

      dynamic "warm_throughput" {
        for_each = lookup(global_secondary_index.value, "warm_throughput_read_units", null) != null || lookup(global_secondary_index.value, "warm_throughput_write_units", null) != null ? [1] : []
        content {
          read_units_per_second  = lookup(global_secondary_index.value, "warm_throughput_read_units", null)
          write_units_per_second = lookup(global_secondary_index.value, "warm_throughput_write_units", null)
        }
      }
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_index
    content {
      name               = local_secondary_index.value.name
      non_key_attributes = lookup(local_secondary_index.value, "non_key_attributes", null)
      projection_type    = local_secondary_index.value.projection_type
      range_key          = local_secondary_index.value.range_key
    }
  }

  dynamic "on_demand_throughput" {
    # if using On Demand (PAY_PER_REQUEST) and max_rcu or max_wcu is set, then create the on_demand_throughput block
    # to avoid unnecessary changes in the Plan
    for_each = var.billing_mode == "PAY_PER_REQUEST" && (var.on_demand_max_rcu != null || var.on_demand_max_wcu != null) ? [1] : []
    content {
      max_read_request_units  = var.on_demand_max_rcu
      max_write_request_units = var.on_demand_max_wcu
    }
  }

  dynamic "warm_throughput" {
    for_each = var.warm_throughput_read_units != null || var.warm_throughput_write_units != null ? [1] : []
    content {
      read_units_per_second  = var.warm_throughput_read_units
      write_units_per_second = var.warm_throughput_write_units
    }
  }

  dynamic "ttl" {
    for_each = var.ttl
    content {
      attribute_name = ttl.value.attribute_name
      enabled        = lookup(ttl.value, "enabled", null)
    }
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  tags = merge(local.table_tags, local.tagging_standard_tags)

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

resource "aws_appautoscaling_target" "read_target" {
  count              = var.enable_autoscaler == "true" ? 1 : 0
  max_capacity       = var.autoscale_max_read_capacity
  min_capacity       = var.autoscale_min_read_capacity
  resource_id        = "table/${aws_dynamodb_table.default.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "read_target_index" {
  count              = var.enable_gsi_autoscaler == "true" ? length(local.dynamodb_indexes) : 0
  max_capacity       = var.autoscale_max_read_capacity_index != null ? var.autoscale_max_read_capacity_index : var.autoscale_max_read_capacity
  min_capacity       = var.autoscale_min_read_capacity_index != null ? var.autoscale_min_read_capacity_index : var.autoscale_min_read_capacity
  resource_id        = "table/${aws_dynamodb_table.default.name}/index/${element(local.dynamodb_indexes, count.index)}"
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = aws_appautoscaling_target.read_target[0].service_namespace
}

resource "aws_appautoscaling_policy" "read_policy" {
  count              = var.enable_autoscaler == "true" ? 1 : 0
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.read_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = var.autoscale_read_target
  }
}

resource "aws_appautoscaling_policy" "read_policy_index" {
  count              = var.enable_gsi_autoscaler == "true" ? length(local.dynamodb_indexes) : 0
  name               = "DynamoDBReadCapacityUtilization:${element(aws_appautoscaling_target.read_target_index.*.resource_id, count.index)}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.read_target_index.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.read_target_index.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.read_target_index.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = var.autoscale_read_target
  }
}

resource "aws_appautoscaling_target" "write_target" {
  count              = var.enable_autoscaler == "true" ? 1 : 0
  max_capacity       = var.autoscale_max_write_capacity
  min_capacity       = var.autoscale_min_write_capacity
  resource_id        = "table/${aws_dynamodb_table.default.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "write_target_index" {
  count              = var.enable_gsi_autoscaler == "true" ? length(local.dynamodb_indexes) : 0
  max_capacity       = var.autoscale_max_write_capacity_index != null ? var.autoscale_max_write_capacity_index : var.autoscale_max_write_capacity
  min_capacity       = var.autoscale_min_write_capacity_index != null ? var.autoscale_min_write_capacity_index : var.autoscale_min_write_capacity
  resource_id        = "table/${aws_dynamodb_table.default.name}/index/${element(local.dynamodb_indexes, count.index)}"
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = aws_appautoscaling_target.write_target[0].service_namespace
}

resource "aws_appautoscaling_policy" "write_policy" {
  count              = var.enable_autoscaler == "true" ? 1 : 0
  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.write_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = var.autoscale_write_target
  }
}

resource "aws_appautoscaling_policy" "write_policy_index" {
  count              = var.enable_gsi_autoscaler == "true" ? length(local.dynamodb_indexes) : 0
  name               = "DynamoDBWriteCapacityUtilization:${element(aws_appautoscaling_target.write_target_index.*.resource_id, count.index)}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.write_target_index.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.write_target_index.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.write_target_index.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = var.autoscale_write_target
  }
}

