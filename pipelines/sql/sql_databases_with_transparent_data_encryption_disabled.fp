locals {
  sql_databases_with_transparent_data_encryption_disabled_query = <<-EOQ
    select
      concat(s.id, ' [', s.subscription_id, '/', s.resource_group, ']') as title,
      s.id as id,
      s.server_name as server_name,
      s.name as name,
      s.resource_group,
      s.subscription_id,
      s._ctx ->> 'connection_name' as conn
    from
      azure_sql_database s,
      azure_subscription sub
    where
      sub.subscription_id = s.subscription_id
      and s.name <> 'master'
      and (transparent_data_encryption ->> 'status' <> 'Enabled' or transparent_data_encryption ->> 'state' = 'Enabled');
  EOQ

  sql_databases_with_transparent_data_encryption_disabled_enabled_actions_enum = ["skip", "enable_sql_db_tde"]
  sql_databases_with_transparent_data_encryption_disabled_default_action_enum = ["notify", "skip", "enable_sql_db_tde"]
}

variable "sql_databases_with_transparent_data_encryption_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "sql_databases_with_transparent_data_encryption_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "sql_databases_with_transparent_data_encryption_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "sql_databases_with_transparent_data_encryption_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_sql_db_tde"]
}

trigger "query" "detect_and_correct_sql_databases_with_transparent_data_encryption_disabled" {
  title         = "Detect & correct SQL Databases with transparent data encryption disabled"
  description   = "Detect SQL Databases with transparent data encryption disabled and enable transparent data encryption."

  enabled  = var.sql_databases_with_transparent_data_encryption_disabled_trigger_enabled
  schedule = var.sql_databases_with_transparent_data_encryption_disabled_trigger_schedule
  database = var.database
  sql      = local.sql_databases_with_transparent_data_encryption_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_sql_databases_with_transparent_data_encryption_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_databases_with_transparent_data_encryption_disabled" {
  title         = "Detect & correct SQL Databases with transparent data encryption disabled"
  description   = "Detect SQL Databases with transparent data encryption disabled and enable transparent data encryption."

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
    default     = var.sql_databases_with_transparent_data_encryption_disabled_default_action
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_with_transparent_data_encryption_disabled_enabled_actions
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_databases_with_transparent_data_encryption_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_databases_with_transparent_data_encryption_disabled
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

pipeline "correct_sql_databases_with_transparent_data_encryption_disabled" {
  title         = "Correct SQL Databases with transparent data encryption disabled"
  description   = "Enable transparent data encryption for SQL Databases with transparent data encryption disabled."

  param "items" {
    type = list(object({
      id              = string
      title           = string
      server_name     = string
      name   = string
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
    default     = var.sql_databases_with_transparent_data_encryption_disabled_default_action
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_with_transparent_data_encryption_disabled_enabled_actions
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} SQL Database(s) with transparent data encryption disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_database_with_transparent_data_encryption_disabled
    args = {
      title              = each.value.title
      server_name        = each.value.server_name
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

pipeline "correct_one_sql_database_with_transparent_data_encryption_disabled" {
  title         = "Correct SQL Database with transparent data encryption disabled"
  description   = "Enable transparent data encryption for a SQL Database with transparent data encryption disabled."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "server_name" {
    type        = string
    description = "The name of the SQL Server."
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
    type        = string
    description = local.description_connection
    default     = "default"
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
    default     = var.sql_databases_with_transparent_data_encryption_disabled_default_action
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_with_transparent_data_encryption_disabled_enabled_actions
    enum        = local.sql_databases_with_transparent_data_encryption_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL Database ${param.title} with Transparent Data Encryption disabled."
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
            text     = "Skipped SQL Database ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_sql_db_tde" = {
          label        = "Enable Transparent Data Encryption"
          value        = "enable_sql_db_tde"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_sql_db_tde
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            server_name     = param.server_name
            database_name   = param.name
            conn            = param.conn
						status          = "Enabled"
          }
          success_msg = "Enabled transparent data tncryption for SQL Database ${param.title}."
          error_msg   = "Error enabling transparent data encryption for SQL Database ${param.title}."
        }
      }
    }
  }
}
