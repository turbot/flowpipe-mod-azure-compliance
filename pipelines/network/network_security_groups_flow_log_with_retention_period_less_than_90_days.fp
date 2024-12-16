locals {
  network_security_groups_flow_log_with_retention_period_less_than_90_days_query = <<-EOQ
    select
      concat(sg.id, ' [', sg.subscription_id, '/', sg.resource_group, ']') as title,
      sg.id as id,
      sg.name,
      sg.resource_group,
      sg.subscription_id,
      sg._ctx ->> 'connection_name' as conn
    from
      azure_network_security_group sg
      left join azure_network_watcher_flow_log fl on sg.id = fl.target_resource_id
    where
      fl.id is null or not fl.enabled or fl.retention_policy_days < 90
  EOQ
}

variable "network_security_groups_flow_log_with_retention_period_less_than_90_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_security_groups_flow_log_with_retention_period_less_than_90_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Network"
  }
}

trigger "query" "detect_and_correct_network_security_groups_flow_log_with_retention_period_less_than_90_days" {
  title         = "Detect & correct NSGs flow log with retention period less than 90 days"
  description   = "Detect NSGs flow log with retention period less than 90 days."
  tags          = local.network_common_tags

  enabled  = var.network_security_groups_flow_log_with_retention_period_less_than_90_days_trigger_enabled
  schedule = var.network_security_groups_flow_log_with_retention_period_less_than_90_days_trigger_schedule
  database = var.database
  sql      = local.network_security_groups_flow_log_with_retention_period_less_than_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_network_security_groups_flow_log_with_retention_period_less_than_90_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_security_groups_flow_log_with_retention_period_less_than_90_days" {
  title         = "Detect & correct NSGs flow log with retention period less than 90 days"
  description   = "Detect NSGs flow log with retention period less than 90 days."
  tags          = local.network_common_tags

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
    sql      = local.network_security_groups_flow_log_with_retention_period_less_than_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_security_groups_flow_log_with_retention_period_less_than_90_days
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_network_security_groups_flow_log_with_retention_period_less_than_90_days" {
  title         = "Correct NSGs flow log with retention period less than 90 days"
  description   = "Send notifications for NSGs flow log with retention period less than 90 days."
  tags         = merge(local.network_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      conn            = string
    }))
    description = local.description_items
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
    text     = "Detected ${length(param.items)} NSG(s) flow log with retention period less than 90 days."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected NSG ${each.value.title} flow log with retention period less than 90 days."
  }
}
