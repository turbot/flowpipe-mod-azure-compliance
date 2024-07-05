locals {
  monitor_common_tags = merge(local.azure_compliance_common_tags, {
    service = "AWS/Monitor"
  })
}
