locals {
  sql_servers_without_active_directory_admin_configured_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_sql_server,
      jsonb_array_elements(encryption_protector) encryption
    where
      server_azure_ad_administrator is null;
  EOQ
}

variable "sql_servers_without_active_directory_admin_configured_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_without_active_directory_admin_configured_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_servers_without_active_directory_admin_configured" {
  title         = "Detect & correct SQL servers without active directory admin configured"
  description   = "Detect SQL servers without active directory admin configured."
  tags          = local.sql_common_tags

  enabled  = var.sql_servers_without_active_directory_admin_configured_trigger_enabled
  schedule = var.sql_servers_without_active_directory_admin_configured_trigger_schedule
  database = var.database
  sql      = local.sql_servers_without_active_directory_admin_configured_query

  capture "insert" {
    pipeline = pipeline.correct_sql_servers_without_active_directory_admin_configured
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_servers_without_active_directory_admin_configured" {
  title         = "Detect & correct SQL servers without active directory admin configured"
  description   = "Send notifications for SQL servers without active directory admin configured."
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
    sql      = local.sql_servers_without_active_directory_admin_configured_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_servers_without_active_directory_admin_configured
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_sql_servers_without_active_directory_admin_configured" {
  title         = "Correct SQL servers without active directory admin configured"
  description   = "Send notifications for SQL servers without active directory admin configured."
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
    text     = "Detected ${length(param.items)} SQL server(s) without active directory admin configured."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected SQL server ${each.value.title} without active directory admin configured."
  }
}