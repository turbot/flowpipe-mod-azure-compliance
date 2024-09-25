locals {
  postgresql_servers_with_log_disconnections_disabled_query = <<-EOQ
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
	    config ->> 'Name' = 'log_disconnections'
	    and lower(config -> 'ConfigurationProperties' ->> 'value') != 'on'
	    and sub.subscription_id = db.subscription_id;
  EOQ
}

variable "postgresql_servers_with_log_disconnections_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "postgresql_servers_with_log_disconnections_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "postgresql_servers_with_log_disconnections_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "postgresql_servers_with_log_disconnections_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_logging_disconnections"]
}

trigger "query" "detect_and_correct_postgresql_servers_with_log_disconnections_disabled" {
  title         = "Detect & correct PostgreSQL servers with logging disconnections disabled"
  description   = "Detect PostgreSQL servers with logging disconnections disabled and then enable logging disconnections."
  tags          = merge(local.postgres_common_tags, { class = "unused" })

  enabled  = var.postgresql_servers_with_log_disconnections_disabled_trigger_enabled
  schedule = var.postgresql_servers_with_log_disconnections_disabled_trigger_schedule
  database = var.database
  sql      = local.postgresql_servers_with_log_disconnections_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgresql_servers_with_log_disconnections_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgresql_servers_with_log_disconnections_disabled" {
  title         = "Detect & correct PostgreSQL servers with logging disconnections disabled"
  description   = "Detects PostgreSQL servers with logging disconnections disabled and then enable logging disconnections."
  tags          = merge(local.postgres_common_tags, { class = "unused", type = "featured" })

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
    default     = var.postgresql_servers_with_log_disconnections_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_disconnections_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgresql_servers_with_log_disconnections_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgresql_servers_with_log_disconnections_disabled
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

pipeline "correct_postgresql_servers_with_log_disconnections_disabled" {
  title         = "Correct PostgreSQL servers with logging disconnections disabled"
  description   = "Enable logging disconnections for PostgreSQL servers with logging disconnections disabled."
  tags          = merge(local.postgres_common_tags, { class = "unused" })

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
    default     = var.postgresql_servers_with_log_disconnections_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_disconnections_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} PostgreSQL server(s) with logging disconnections disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgresql_server_with_log_disconnections_disabled
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

pipeline "correct_one_postgresql_server_with_log_disconnections_disabled" {
  title         = "Correct PostgreSQL server with logging disconnections disabled"
  description   = "Enable logging disconnections for a PostgreSQL server with logging disconnections disabled."
  tags          = merge(local.postgres_common_tags, { class = "unused" })

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
    default     = var.postgresql_servers_with_log_disconnections_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_log_disconnections_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL server ${param.title} with logging disconnections disabled."
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
            text     = "Skipped PostgreSQL server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_logging_disconnections" = {
          label        = "Enable logging disconnections"
          value        = "enable_logging_disconnections"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_set_postgres_server_configuration
          pipeline_args = {
            server_name       = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            cred              = param.cred
            config_name       = "log_disconnections"
            config_value      = "on"
          }
          success_msg = "Enabled logging disconnections for PostgreSQL server ${param.title}."
          error_msg   = "Error enabling logging disconnections for PostgreSQL server ${param.title}."
        }
      }
    }
  }
}
