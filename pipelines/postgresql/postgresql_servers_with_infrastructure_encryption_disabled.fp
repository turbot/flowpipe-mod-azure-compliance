locals {
  postgresql_servers_with_infrastructure_encryption_disabled_query = <<-EOQ
   	select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_postgresql_server
    where
      not (public_network_access = 'Enabled');
  EOQ
}

variable "postgresql_servers_with_infrastructure_encryption_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_servers_with_infrastructure_encryption_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

trigger "query" "detect_and_correct_postgresql_servers_with_infrastructure_encryption_disabled" {
  title         = "Detect & correct PostgreSQL servers with infrastructure encryption disabled"
  description   = "Detect PostgreSQL servers with infrastructure encryption disabled."
  tags          = local.postgresql_common_tags

  enabled  = var.postgresql_servers_with_infrastructure_encryption_disabled_trigger_enabled
  schedule = var.postgresql_servers_with_infrastructure_encryption_disabled_trigger_schedule
  database = var.database
  sql      = local.postgresql_servers_with_infrastructure_encryption_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgresql_servers_with_infrastructure_encryption_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgresql_servers_with_infrastructure_encryption_disabled" {
  title         = "Detect & correct PostgreSQL servers with infrastructure encryption disabled"
  description   = "Detect PostgreSQL servers with infrastructure encryption disabled."
  tags          = local.postgresql_common_tags

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
    sql      = local.postgresql_servers_with_infrastructure_encryption_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgresql_servers_with_infrastructure_encryption_disabled
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_postgresql_servers_with_infrastructure_encryption_disabled" {
  title         = "Correct PostgreSQL servers with infrastructure encryption disabled"
  description   = "Send notifications for PostgreSQL servers with infrastructure encryption disabled."
  tags          = merge(local.postgresql_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} PostgreSQL server(s) with infrastructure encryption disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected PostgreSQL server ${each.value.title} with infrastructure encryption disabled."
  }
}