locals {
  postgresql_servers_with_log_retention_less_than_3_days_query = <<-EOQ
    select
      concat(db.id, ' [', db.subscription_id, '/', db.resource_group, ']') as title,
	    db.id as id,
	    db.name,
      db.resource_group,
      db.subscription_id,
      db._ctx ->> 'connection_name' as cred
    from
      azure_postgresql_server as db,
      jsonb_array_elements(server_configurations) config,
	    azure_subscription as sub
	  where
      config ->> 'Name' = 'log_retention_days'
      and (config -> 'ConfigurationProperties' ->> 'value') :: integer <= 3
      and sub.subscription_id = db.subscription_id;
  EOQ
}

variable "postgresql_servers_with_log_retention_less_than_3_days_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "postgresql_servers_with_log_retention_less_than_3_days_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "postgresql_servers_with_log_retention_less_than_3_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "postgresql_servers_with_log_retention_less_than_3_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_log_retention_days"]
}

variable "log_retention_days" {
  type        = string
  description = "The number of days logs should be retained."
  default     = "7"
}

trigger "query" "detect_and_correct_postgresql_servers_with_log_retention_less_than_3_days" {
  title         = "Detect & correct PostgreSQL servers with log retention less than 3 days"
  description   = "Detect PostgreSQL servers with log retention less than 3 and then sets log retention to 3 or more than 3 days."

  enabled  = var.postgresql_servers_with_log_retention_less_than_3_days_trigger_enabled
  schedule = var.postgresql_servers_with_log_retention_less_than_3_days_trigger_schedule
  database = var.database
  sql      = local.postgresql_servers_with_log_retention_less_than_3_days_query

  capture "insert" {
    pipeline = pipeline.correct_postgresql_servers_with_log_retention_less_than_3_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgresql_servers_with_log_retention_less_than_3_days" {
  title         = "Detect & correct PostgreSQL servers with log retention less than 3 days"
  description   = "Detect PostgreSQL servers with log retention less than 3 and then sets log retention to 3 or more than 3 days."

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgresql_servers_with_log_retention_less_than_3_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgresql_servers_with_log_retention_less_than_3_days
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

pipeline "correct_postgresql_servers_with_log_retention_less_than_3_days" {
  title         = "Correct PostgreSQL servers with log retention less than 3 days"
  description   = "Update log retention days to 3 or more for PostgreSQL servers with log retention less than 3 days."

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      resource_group  = string
      subscription_id = string
      cred            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} PostgreSQL server(s) with log retention_days less than 3 days."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgresql_server_with_log_retention_less_than_3_days
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_postgresql_server_with_log_retention_less_than_3_days" {
  title         = "Correct PostgreSQL server with log retention less than 3 days"
  description   = "Update log retention days to 3 or more for a PostgreSQL server with log retention less than 3 days."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the PostgreSQL server."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

   param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_retention_less_than_3_days_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL server ${param.title} with log retention less than 3 days."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped PostgreSQL DB server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_log_retention_days" = {
          label        = "Update log retention days"
          value        = "update_log_retention_days"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_set_postgres_server_configuration
          pipeline_args = {
            server_name       = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            cred              = param.cred
            config_name       = "log_retention_days"
            config_value      = var.log_retention_days
          }
          success_msg = "Updated log retention days for PostgreSQL server ${param.title}."
          error_msg   = "Error updating log retention days for PostgreSQL server ${param.title}."
        }
      }
    }
  }
}

