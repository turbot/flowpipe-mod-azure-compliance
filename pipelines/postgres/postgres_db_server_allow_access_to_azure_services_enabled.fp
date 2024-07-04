locals {
  postgres_db_server_allow_access_to_azure_services_enabled_query = <<-EOQ
    with postgres_db_with_allow_access_to_azure_services as (
      select
        id
      from
        azure_postgresql_server,
        jsonb_array_elements(firewall_rules) as r
      where
        r -> 'FirewallRuleProperties' ->> 'endIpAddress' = '0.0.0.0'
        and r -> 'FirewallRuleProperties' ->> 'startIpAddress' = '0.0.0.0'
    )
    select
      concat(db.id, ' [', db.resource_group, '/', db.subscription_id, ']') as title,
      db.id as id,
      db.name,
      db.resource_group,
      db.subscription_id,
      db._ctx ->> 'connection_name' as cred
    from
      azure_postgresql_server as db,
      postgres_db_with_allow_access_to_azure_services as a,
      azure_subscription as sub
    where
      a.id is not null
      and sub.subscription_id = db.subscription_id;
  EOQ
}

variable "postgres_db_server_allow_access_to_azure_services_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "postgres_db_server_allow_access_to_azure_services_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "postgres_db_server_allow_access_to_azure_services_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "postgres_db_server_allow_access_to_azure_services_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_firewall_rule"]
}

trigger "query" "detect_and_correct_postgres_db_server_allow_access_to_azure_services_enabled" {
  title         = "Detect & correct PostgreSQL DB servers allowing access to Azure services"
  description   = "Detects PostgreSQL database servers allowing access to Azure services and runs your chosen action."
  tags          = merge(local.postgres_common_tags, { class = "unused" })

  enabled  = var.postgres_db_server_allow_access_to_azure_services_enabled_trigger_enabled
  schedule = var.postgres_db_server_allow_access_to_azure_services_enabled_trigger_schedule
  database = var.database
  sql      = local.postgres_db_server_allow_access_to_azure_services_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgres_db_server_allow_access_to_azure_services_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgres_db_server_allow_access_to_azure_services_enabled" {
  title         = "Detect & correct PostgreSQL DB servers allowing access to Azure services"
  description   = "Detects PostgreSQL database servers allowing access to Azure services and runs your chosen action."
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
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgres_db_server_allow_access_to_azure_services_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgres_db_server_allow_access_to_azure_services_enabled
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

pipeline "correct_postgres_db_server_allow_access_to_azure_services_enabled" {
  title         = "Correct PostgreSQL DB servers allowing access to Azure services"
  description   = "Runs corrective action on a collection of PostgreSQL database servers allowing access to Azure services."
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
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} PostgreSQL DB servers allowing access to Azure services."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgres_db_server_allow_access_to_azure_services_enabled
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

pipeline "correct_one_postgres_db_server_allow_access_to_azure_services_enabled" {
  title         = "Correct one PostgreSQL DB server allowing access to Azure services"
  description   = "Runs corrective action on a single PostgreSQL database server allowing access to Azure services."
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
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgres_db_server_allow_access_to_azure_services_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL DB server ${param.title} allowing access to Azure services."
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
            text     = "Skipped PostgreSQL DB server ${param.title} allowing access to Azure services."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_firewall_rule" = {
          label        = "Delete Firewall Rule"
          value        = "delete_firewall_rule"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_postgres_server_firewall_rule
          pipeline_args = {
            resource_group     = param.resource_group
            subscription_id    = param.subscription_id
            server_name        = param.name
            cred               = param.cred
            firewall_rule_name = "AllowAllWindowsAzureIps"
          }
          success_msg = "Deleted firewall rule allowing access to Azure services for PostgreSQL DB server ${param.title}."
          error_msg   = "Error deleting firewall rule allowing access to Azure services for PostgreSQL DB server ${param.title}."
        }
      }
    }
  }
}
