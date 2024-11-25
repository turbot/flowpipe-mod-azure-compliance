locals {
  sql_servers_with_public_network_access_enabled_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name as name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_sql_server
    where
      public_network_access = 'Enabled';
  EOQ

  sql_servers_with_public_network_access_enabled_enabled_actions_enum = ["skip", "disable_public_network_access"]
  sql_servers_with_public_network_access_enabled_default_action_enum  = ["notify", "skip", "disable_public_network_access"]
}

variable "sql_servers_with_public_network_access_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_with_public_network_access_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_with_public_network_access_enabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_with_public_network_access_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "disable_public_network_access"]

  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_servers_with_public_network_access_enabled" {
  title         = "Detect & correct SQL servers with public network access enabled"
  description   = "Detect SQL serevrs with public network access enabled and then disable public network access."
  tags          = local.sql_common_tags

  enabled  = var.sql_servers_with_public_network_access_enabled_trigger_enabled
  schedule = var.sql_servers_with_public_network_access_enabled_trigger_schedule
  database = var.database
  sql      = local.sql_servers_with_public_network_access_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_sql_servers_with_public_network_access_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_servers_with_public_network_access_enabled" {
  title         = "Detect & correct SQL servers with public network access enabled"
  description   = "Detect SQL serevrs with public network access enabled and then disable public network access."
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.sql_servers_with_public_network_access_enabled_default_action
    enum        = local.sql_servers_with_public_network_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_with_public_network_access_enabled_enabled_actions
    enum        = local.sql_servers_with_public_network_access_enabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_servers_with_public_network_access_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_servers_with_public_network_access_enabled
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

pipeline "correct_sql_servers_with_public_network_access_enabled" {
  title         = "Correct SQL servers with public network access enabled"
  description   = "Disable public network access for SQL servers with public network access enabled."
  tags         = merge(local.sql_common_tags, { folder = "Internal" })

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
    default     = var.sql_servers_with_public_network_access_enabled_default_action
    enum        = local.sql_servers_with_public_network_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_with_public_network_access_enabled_enabled_actions
    enum        = local.sql_servers_with_public_network_access_enabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} SQL server(s) with public network access enabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_server_with_public_network_access_enabled
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

pipeline "correct_one_sql_server_with_public_network_access_enabled" {
  title         = "Correct SQL servers with public network access enabled"
  description   = "Disable public network access for a SQL servers with public network access enabled."
  tags         = merge(local.sql_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the SQL Database."
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
    default     = var.sql_servers_with_public_network_access_enabled_default_action
    enum        = local.sql_servers_with_public_network_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_with_public_network_access_enabled_enabled_actions
    enum        = local.sql_servers_with_public_network_access_enabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL server ${param.title} with public network access enabled."
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
            text     = "Skipped SQL server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "disable_public_network_access" = {
          label        = "Disable public network access"
          value        = "disable_public_network_access"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_sql_server_public_network
          pipeline_args = {
            resource_group        = param.resource_group
            subscription_id       = param.subscription_id
            server_name           = param.name
            conn                  = param.conn
					  enable_public_network = false
          }
          success_msg = "Disabled public network access for SQL server ${param.title}."
          error_msg   = "Error disabling public network access for SQL server ${param.title}."
        }
      }
    }
  }
}
