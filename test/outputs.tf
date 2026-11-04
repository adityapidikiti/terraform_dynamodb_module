# Outputs of the module calls above, so that test assertions have something to
# read. Terraform test can only assert on what the configuration exposes.

output "basic" {
  description = "Results for the minimal on-demand table."
  value = {
    name = module.basic.table_name
    id   = module.basic.table_id
    arn  = module.basic.table_arn
  }
}

output "provisioned_autoscaling_gsi" {
  description = "Results for the provisioned table with autoscaling, a GSI and a stream."
  value = {
    name         = module.provisioned_autoscaling_gsi.table_name
    id           = module.provisioned_autoscaling_gsi.table_id
    arn          = module.provisioned_autoscaling_gsi.table_arn
    stream_arn   = module.provisioned_autoscaling_gsi.table_stream_arn
    stream_label = module.provisioned_autoscaling_gsi.table_stream_label
  }
}

output "ondemand_limits_ttl" {
  description = "Results for the on-demand table with throughput ceilings and TTL."
  value = {
    name = module.ondemand_limits_ttl.table_name
    id   = module.ondemand_limits_ttl.table_id
    arn  = module.ondemand_limits_ttl.table_arn
  }
}

output "standard_ia_no_pitr" {
  description = "Results for the STANDARD_INFREQUENT_ACCESS table without PITR."
  value = {
    name = module.standard_ia_no_pitr.table_name
    id   = module.standard_ia_no_pitr.table_id
    arn  = module.standard_ia_no_pitr.table_arn
  }
}
