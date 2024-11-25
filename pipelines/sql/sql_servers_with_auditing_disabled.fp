locals {
  sql_servers_with_auditing_disabled_query = <<-EOQ
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
      audit -> 'properties' ->> 'state' = 'Disabled';
  EOQ
}

variable "sql_servers_with_auditing_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_with_auditing_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_servers_with_auditing_disabled" {
  title         = "Detect & correct SQL servers with auditing disabled"
  description   = "Detect SQL servers with auditing disabled."
  tags          = local.sql_common_tags

  enabled  = var.sql_servers_with_auditing_disabled_trigger_enabled
  schedule = var.sql_servers_with_auditing_disabled_trigger_schedule
  database = var.database
  sql      = local.sql_servers_with_auditing_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_sql_servers_with_auditing_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_servers_with_auditing_disabled" {
  title         = "Detect & correct SQL servers with auditing disabled"
  description   = "Detect SQL servers with auditing disabled."
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
    sql      = local.sql_servers_with_auditing_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_servers_with_auditing_disabled
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_sql_servers_with_auditing_disabled" {
  title         = "Correct SQL servers with auditing disabled"
  description   = "Send notifications for SQL servers with auditing disabled."
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
    text     = "Detected ${length(param.items)} SQL server(s) with auditing disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected SQL server ${each.value.title} with auditing disabled."
  }
}