locals {
  postgres_db_server_ssl_disabled_query = <<-EOQ
    select
      concat(db.id, ' [', db.resource_group, '/', db.subscription_id, ']') as title,
      db.id as id,
      db.name,
      db.resource_group,
      db.subscription_id,
      db._ctx ->> 'connection_name' as cred
    from
      azure_postgresql_server as db,
      azure_subscription as sub
    where
      ssl_enforcement = 'Disabled'
      and sub.subscription_id = db.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_postgres_db_server_ssl_disabled" {
  title         = "Detect & correct PostgreSQL DB servers with SSL disabled"
  description   = "Detects PostgreSQL database servers with SSL disabled and runs your chosen action."
  // documentation = file("./postgres/docs/detect_and_correct_postgres_db_server_ssl_disabled_trigger.md")
  tags          = merge(local.postgres_common_tags, { class = "unused" })

  enabled  = var.postgres_db_server_ssl_disabled_trigger_enabled
  schedule = var.postgres_db_server_ssl_disabled_trigger_schedule
  database = var.database
  sql      = local.postgres_db_server_ssl_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgres_db_server_ssl_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgres_db_server_ssl_disabled" {
  title         = "Detect & correct PostgreSQL DB servers with SSL disabled"
  description   = "Detects PostgreSQL database servers with SSL disabled and runs your chosen action."
  // documentation = file("./postgres/docs/detect_and_correct_postgres_db_server_ssl_disabled.md")
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
    default     = var.postgres_db_server_ssl_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_ssl_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgres_db_server_ssl_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgres_db_server_ssl_disabled
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

pipeline "correct_postgres_db_server_ssl_disabled" {
  title         = "Correct PostgreSQL DB servers with SSL disabled"
  description   = "Runs corrective action on a collection of PostgreSQL database servers with SSL disabled."
  // documentation = file("./postgres/docs/correct_postgres_db_server_ssl_disabled.md")
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
    default     = var.postgres_db_server_ssl_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_ssl_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} PostgreSQL DB servers with SSL disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgres_db_server_ssl_disabled
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

pipeline "correct_one_postgres_db_server_ssl_disabled" {
  title         = "Correct one PostgreSQL DB server with SSL disabled"
  description   = "Runs corrective action on a single PostgreSQL database server with SSL disabled."
  // documentation = file("./postgres/docs/correct_one_postgres_db_server_ssl_disabled.md")
  tags          = merge(local.postgres_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the PostgreSQL database server."
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
    default     = var.postgres_db_server_ssl_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_ssl_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL DB server ${param.title} with SSL disabled."
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
            text     = "Skipped PostgreSQL DB server ${param.title} with SSL disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_ssl" = {
          label        = "Enable SSL"
          value        = "enable_ssl"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_postgres_server_ssl_enforcement
          pipeline_args = {
            server_name       = param.name
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            cred              = param.cred
            ssl_enforcement   = "Enabled"
          }
          success_msg = "Enabled SSL for PostgreSQL DB server ${param.title}."
          error_msg   = "Error enabling SSL for PostgreSQL DB server ${param.title}."
        }
      }
    }
  }
}

variable "postgres_db_server_ssl_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "postgres_db_server_ssl_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "postgres_db_server_ssl_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "enable_ssl"
}

variable "postgres_db_server_ssl_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_ssl"]
}
