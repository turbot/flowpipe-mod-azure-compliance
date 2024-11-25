locals {
  sql_servers_with_auditing_retention_period_less_than_90_days_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_sql_server,
      jsonb_array_elements(server_audit_policy) audit
    where
      not ((audit -> 'properties' ->> 'retentionDays')::integer >= 90);
  EOQ
}

variable "sql_servers_with_auditing_retention_period_less_than_90_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_with_auditing_retention_period_less_than_90_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_servers_with_auditing_retention_period_less_than_90_days" {
  title         = "Detect & correct SQL servers with auditing retention period less than 90 days"
  description   = "Detect SQL servers with auditing retention period less than 90 days."
  tags          = local.sql_common_tags

  enabled  = var.sql_servers_with_auditing_retention_period_less_than_90_days_trigger_enabled
  schedule = var.sql_servers_with_auditing_retention_period_less_than_90_days_trigger_schedule
  database = var.database
  sql      = local.sql_servers_with_auditing_retention_period_less_than_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_sql_servers_with_auditing_retention_period_less_than_90_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_servers_with_auditing_retention_period_less_than_90_days" {
  title         = "Detect & correct SQL servers with auditing retention period less than 90 days"
  description   = "Detect SQL servers with auditing retention period less than 90 days."
  tags          = local.sql_common_tags

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
    sql      = local.sql_servers_with_auditing_retention_period_less_than_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_servers_with_auditing_retention_period_less_than_90_days
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_sql_servers_with_auditing_retention_period_less_than_90_days" {
  title         = "Correct SQL servers with auditing retention period less than 90 days"
  description   = "Send notifications for SQL servers with auditing retention period less than 90 days."
  tags          = merge(local.sql_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} SQL server(s) with auditing retention period less than 90 days."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected SQL server ${each.value.title} with auditing retention period less than 90 days."
  }
}