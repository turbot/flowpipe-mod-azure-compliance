
locals {
  monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query = <<-EOQ
    select
      concat(a.id, ' [', a.subscription_id, '/', a.resource_group, ']') as title,
      a.id as id,
      a.name,
      a.resource_group,
      a.subscription_id,
      a._ctx ->> 'connection_name' as conn
    from
      azure_storage_container c,
      azure_storage_account a
    where
      c.name = 'insights-activity-logs'
      and c.account_name = a.name
      and a.encryption_key_source <> 'Microsoft.Keyvault';
  EOQ
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Detect & correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Detect Storage account containers insights activity logs not encrypted with CMK and then enable encryption using CMK."

  tags = local.monitor_common_tags

  enabled  = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_enabled
  schedule = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_schedule
  database = var.database
  sql      = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Detect & correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Detect Storage containers insights activity logs not encrypted with CMK and then enable encryption using CMK."

  tags = local.monitor_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Executes corrective actions on Storage account containers insights activity logs not encrypted with CMK."
  tags = merge(local.monitor_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      conn            = string
    }))
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage account container(s) insights activity logs not encrypted with CMK."
  }

 step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Storage account ${each.value.title} container(s) insights activity logs not encrypted with CMK."
  }
}