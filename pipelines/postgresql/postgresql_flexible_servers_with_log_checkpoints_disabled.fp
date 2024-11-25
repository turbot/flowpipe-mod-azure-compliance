locals {
  postgresql_flexible_servers_with_log_checkpoints_disabled_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_postgresql_flexible_server as db,
      jsonb_array_elements(flexible_server_configurations) config
    where
      config ->> 'Name' = 'log_checkpoints'
      and lower(config -> 'ConfigurationProperties' ->> 'value') != 'on';
  EOQ

  postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions_enum = ["skip", "enable_log_checkpoints"]
  postgresql_flexible_servers_with_log_checkpoints_disabled_default_action_enum = ["notify", "skip", "enable_log_checkpoints"]
}

variable "postgresql_flexible_servers_with_log_checkpoints_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_flexible_servers_with_log_checkpoints_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_flexible_servers_with_log_checkpoints_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_log_checkpoints"]

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

trigger "query" "detect_and_correct_postgresql_flexible_servers_with_log_checkpoints_disabled" {
  title         = "Detect & correct PostgreSQL flexible servers with log checkpoints disabled"
  description   = "Detect PostgreSQL flexible servers with log checkpoints disabled and then enable log checkpoints."
  tags          = local.postgresql_common_tags

  enabled  = var.postgresql_flexible_servers_with_log_checkpoints_disabled_trigger_enabled
  schedule = var.postgresql_flexible_servers_with_log_checkpoints_disabled_trigger_schedule
  database = var.database
  sql      = local.postgresql_flexible_servers_with_log_checkpoints_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgresql_flexible_servers_with_log_checkpoints_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgresql_flexible_servers_with_log_checkpoints_disabled" {
  title         = "Detect & correct PostgreSQL flexible servers with log checkpoints disabled"
  description   = "Detect PostgreSQL flexible servers with log checkpoints disabled and then enable log checkpoints."
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgresql_flexible_servers_with_log_checkpoints_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgresql_flexible_servers_with_log_checkpoints_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_postgresql_flexible_servers_with_log_checkpoints_disabled" {
  title         = "Correct PostgreSQL flexible servers with log checkpoints disabled"
  description   = "Enable log checkpoints for PostgreSQL flexible servers with log checkpoints disabled."
  tags          = merge(local.postgresql_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      resource_group  = string
      subscription_id = string
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} PostgreSQL flexible server(s) with log checkpoints disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgresql_flexible_server_with_log_checkpoints_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_postgresql_flexible_server_with_log_checkpoints_disabled" {
  title         = "Correct PostgreSQL flexible server with log checkpoints disabled"
  description   = "Enable log checkpoints for a PostgreSQL flexible server with log checkpoints disabled."
  tags          = merge(local.postgresql_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the PostgreSQL flexible server."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "conn" {
    type        = connection.azure
    description = local.description_connection
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

   param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions
    enum        = local.postgresql_flexible_servers_with_log_checkpoints_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL flexible server ${param.title} with log checkpoints disabled."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_info
            text     = "Skipped PostgreSQL flexible server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_log_checkpoints" = {
          label        = "Enable log checkpoints"
          value        = "enable_log_checkpoints"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_postgres_flexible_server_configuration
          pipeline_args = {
            server_name       = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            conn              = param.conn
            config_name       = "log_checkpoints"
            config_value      = "on"
          }
          success_msg = "Enabled log checkpoints for PostgreSQL flexible server ${param.title}."
          error_msg   = "Error enabling log checkpoints for PostgreSQL flexible server ${param.title}."
        }
      }
    }
  }
}
