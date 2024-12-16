locals {
  mysql_flexible_servers_with_ssl_disabled_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name as server_name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_mysql_flexible_server,
      jsonb_array_elements(flexible_server_configurations) as config
    where
      config ->> 'Name' = 'require_secure_transport'
      and config -> 'ConfigurationProperties' ->> 'value' <> 'ON';
  EOQ

  mysql_flexible_servers_with_ssl_disabled_enabled_actions_enum = ["skip", "set_parameter_require_secure_transport"]
  mysql_flexible_servers_with_ssl_disabled_default_action_enum  = ["notify", "skip", "set_parameter_require_secure_transport"]
}

variable "mysql_flexible_servers_with_ssl_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/MySQL"
  }
}

variable "mysql_flexible_servers_with_ssl_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/MySQL"
  }
}

variable "mysql_flexible_servers_with_ssl_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "set_parameter_require_secure_transport"]

  tags = {
    folder = "Advanced/MySQL"
  }
}

variable "mysql_flexible_servers_with_ssl_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "set_parameter_require_secure_transport"]
  enum        = ["skip", "set_parameter_require_secure_transport"]

  tags = {
    folder = "Advanced/MySQL"
  }
}

trigger "query" "detect_and_correct_mysql_flexible_servers_with_ssl_disabled" {
  title       = "Detect & correct MySQL flexible servers with SSL disabled"
  description = "Detect MySQL flexible servers with SSL disabled and then enable SSL."
  tags        = merge(local.mysql_common_tags, { recommended = "true" })

  enabled  = var.mysql_flexible_servers_with_ssl_disabled_trigger_enabled
  schedule = var.mysql_flexible_servers_with_ssl_disabled_trigger_schedule
  database = var.database
  sql      = local.mysql_flexible_servers_with_ssl_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_mysql_flexible_servers_with_ssl_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_mysql_flexible_servers_with_ssl_disabled" {
  title       = "Detect & correct MySQL flexible servers with SSL disabled"
  description = "Detect MySQL flexible servers with SSL disabled and then enable SSL."
  tags        = local.mysql_common_tags

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
    default     = var.mysql_flexible_servers_with_ssl_disabled_default_action
    enum        = local.mysql_flexible_servers_with_ssl_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.mysql_flexible_servers_with_ssl_disabled_enabled_actions
    enum        = local.mysql_flexible_servers_with_ssl_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.mysql_flexible_servers_with_ssl_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_mysql_flexible_servers_with_ssl_disabled
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

pipeline "correct_mysql_flexible_servers_with_ssl_disabled" {
  title       = "Correct MySQL flexible servers with SSL disabled"
  description = "Enable SSL for MySQL flexible servers with SSL disabled."
  tags        = merge(local.mysql_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      server_name     = string
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
    default     = var.mysql_flexible_servers_with_ssl_disabled_default_action
    enum        = local.mysql_flexible_servers_with_ssl_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.mysql_flexible_servers_with_ssl_disabled_enabled_actions
    enum        = local.mysql_flexible_servers_with_ssl_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} MySQL flexible server(s) with SSL disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_mysql_flexible_server_with_ssl_disabled
    args = {
      title              = each.value.title
      server_name        = each.value.server_name
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

pipeline "correct_one_mysql_flexible_server_with_ssl_disabled" {
  title       = "Correct MySQL flexible server with SSL disabled"
  description = "Enable SSL for a MySQL flexible server with SSL disabled"
  tags        = merge(local.mysql_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "server_name" {
    type        = string
    description = "The name of the MySQL flexible server."
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
    default     = var.mysql_flexible_servers_with_ssl_disabled_default_action
    enum        = local.mysql_flexible_servers_with_ssl_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.mysql_flexible_servers_with_ssl_disabled_enabled_actions
    enum        = local.mysql_flexible_servers_with_ssl_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected MySQL flexible server ${param.title} with SSL disabled."
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
            text     = "Skipped MySQL flexible server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "set_parameter_require_secure_transport" = {
          label        = "Set require secure transport parameter to 'On'"
          value        = "set_parameter_require_secure_transport"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_mysql_flexible_server_parameter
          pipeline_args = {
            server_name        = param.server_name
            resource_group     = param.resource_group
            subscription_id    = param.subscription_id
            conn               = param.conn
            parameter_name     = "require_secure_transport"
            parameter_value    = "ON"
          }
          success_msg = "Enabled SSL for MySQL flexible server ${param.title}."
          error_msg   = "Error enabling SSL for MySQL flexible server ${param.title}."
        }
      }
    }
  }
}
