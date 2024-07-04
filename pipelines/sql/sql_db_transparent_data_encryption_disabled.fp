locals {
  sql_db_transparent_data_encryption_disabled_query = <<-EOQ
    select
      concat(s.id, ' [', s.resource_group, '/', s.subscription_id, ']') as title,
      s.id as id,
      s.server_name as server_name,
      s.name as name,
      s.resource_group,
      s.subscription_id,
      s._ctx ->> 'connection_name' as cred
    from
      azure_sql_database s,
      azure_subscription sub
    where
      sub.subscription_id = s.subscription_id
			and s.name <> 'master'
      and (transparent_data_encryption ->> 'status' <> 'Enabled' or transparent_data_encryption ->> 'state' = 'Enabled');
  EOQ
}

trigger "query" "detect_and_correct_sql_db_transparent_data_encryption_disabled" {
  title         = "Detect & correct SQL Databases with Transparent Data Encryption disabled"
  description   = "Detects SQL Databases with Transparent Data Encryption disabled and runs your chosen action."
  // documentation = file("./sql/docs/detect_and_correct_sql_db_transparent_data_encryption_disabled_trigger.md")
  tags          = merge(local.sql_common_tags, { class = "security" })

  enabled  = var.sql_db_transparent_data_encryption_disabled_trigger_enabled
  schedule = var.sql_db_transparent_data_encryption_disabled_trigger_schedule
  database = var.database
  sql      = local.sql_db_transparent_data_encryption_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_sql_db_transparent_data_encryption_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_db_transparent_data_encryption_disabled" {
  title         = "Detect & correct SQL Databases with Transparent Data Encryption disabled"
  description   = "Detects SQL Databases with Transparent Data Encryption disabled and runs your chosen action."
  // documentation = file("./sql/docs/detect_and_correct_sql_db_transparent_data_encryption_disabled.md")
  tags          = merge(local.sql_common_tags, { class = "security", type = "featured" })

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
    default     = var.sql_db_transparent_data_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_transparent_data_encryption_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_db_transparent_data_encryption_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_db_transparent_data_encryption_disabled
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

pipeline "correct_sql_db_transparent_data_encryption_disabled" {
  title         = "Correct SQL Databases with Transparent Data Encryption disabled"
  description   = "Runs corrective action on a collection of SQL Databases with Transparent Data Encryption disabled."
  // documentation = file("./sql/docs/correct_sql_db_transparent_data_encryption_disabled.md")
  tags          = merge(local.sql_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      server_name     = string
      name   = string
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
    default     = var.sql_db_transparent_data_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_transparent_data_encryption_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} SQL Databases with Transparent Data Encryption disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_db_transparent_data_encryption_disabled
    args = {
      title              = each.value.title
      server_name        = each.value.server_name
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

pipeline "correct_one_sql_db_transparent_data_encryption_disabled" {
  title         = "Correct one SQL Database with Transparent Data Encryption disabled"
  description   = "Runs corrective action on a single SQL Database with Transparent Data Encryption disabled."
  // documentation = file("./sql/docs/correct_one_sql_db_transparent_data_encryption_disabled.md")
  tags          = merge(local.sql_common_tags, { class = "security" })

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
    default     = var.sql_db_transparent_data_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_transparent_data_encryption_disabled_enabled_actions
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
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped SQL Database ${param.title} with Transparent Data Encryption disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_sql_db_tde" = {
          label        = "Enable Transparent Data Encryption"
          value        = "enable_sql_db_tde"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_set_sql_db_tde
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            server_name     = param.server_name
            database_name   = param.name
            cred            = param.cred
						status          = "Enabled"
          }
          success_msg = "Enabled Transparent Data Encryption for SQL Database ${param.title}."
          error_msg   = "Error enabling Transparent Data Encryption for SQL Database ${param.title}."
        }
      }
    }
  }
}

variable "sql_db_transparent_data_encryption_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "sql_db_transparent_data_encryption_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "sql_db_transparent_data_encryption_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "enable_sql_db_tde"
}

variable "sql_db_transparent_data_encryption_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_sql_db_tde"]
}
