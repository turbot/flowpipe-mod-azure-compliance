locals {
  postgresql_servers_with_allow_access_to_azure_services_enabled_query = <<-EOQ
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
      concat(db.id, ' [', db.subscription_id, '/', db.resource_group, ']') as title,
      db.id as id,
      db.name,
      db.resource_group,
      db.subscription_id,
      db._ctx ->> 'connection_name' as conn
    from
      azure_postgresql_server as db,
      postgres_db_with_allow_access_to_azure_services as a,
      azure_subscription as sub
    where
      a.id is not null
      and sub.subscription_id = db.subscription_id;
  EOQ

  postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions_enum = ["skip", "delete_allow_all_windows_azure_ips_firewall_rule"]
  postgresql_servers_with_allow_access_to_azure_services_enabled_default_action_enum = ["notify", "skip", "delete_allow_all_windows_azure_ips_firewall_rule"]
}

variable "postgresql_servers_with_allow_access_to_azure_services_enabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_servers_with_allow_access_to_azure_services_enabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_servers_with_allow_access_to_azure_services_enabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

variable "postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_allow_all_windows_azure_ips_firewall_rule"]

  tags = {
    folder = "Advanced/PostgreSQL"
  }
}

trigger "query" "detect_and_correct_postgresql_servers_with_allow_access_to_azure_services_enabled" {
  title         = "Detect & correct PostgreSQL servers allowing access to Azure services"
  description   = "Detect PostgreSQL servers allowing access to Azure services and then disable access to Azure services."
  tags          = local.postgresql_common_tags

  enabled  = var.postgresql_servers_with_allow_access_to_azure_services_enabled_trigger_enabled
  schedule = var.postgresql_servers_with_allow_access_to_azure_services_enabled_trigger_schedule
  database = var.database
  sql      = local.postgresql_servers_with_allow_access_to_azure_services_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_postgresql_servers_with_allow_access_to_azure_services_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_postgresql_servers_with_allow_access_to_azure_services_enabled" {
  title         = "Detect & correct PostgreSQL servers allowing access to Azure services"
  description   = "Detect PostgreSQL servers allowing access to Azure services and then disable access to Azure services."
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
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.postgresql_servers_with_allow_access_to_azure_services_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_postgresql_servers_with_allow_access_to_azure_services_enabled
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

pipeline "correct_postgresql_servers_with_allow_access_to_azure_services_enabled" {
  title         = "Correct PostgreSQL servers allowing access to Azure services"
  description   = "Disable access to Azure services for PostgreSQL servers with enabled access to Azure services."
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
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} PostgreSQL server(s) allowing access to Azure services."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_postgresql_servers_with_allow_access_to_azure_services_enabled
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

pipeline "correct_one_postgresql_servers_with_allow_access_to_azure_services_enabled" {
  title         = "Correct PostgreSQL server allowing access to Azure services"
  description   = "Disable access to Azure services for a PostgreSQL server with enabled access to Azure services."
  tags          = merge(local.postgresql_common_tags, { folder = "Internal" })

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
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions
    enum        = local.postgresql_servers_with_allow_access_to_azure_services_enabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected PostgreSQL server ${param.title} allowing access to Azure services."
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
            text     = "Skipped PostgreSQL server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_allow_all_windows_azure_ips_firewall_rule" = {
          label        = "Delete Firewall Rule"
          value        = "delete_allow_all_windows_azure_ips_firewall_rule"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_postgres_server_firewall_rule
          pipeline_args = {
            resource_group     = param.resource_group
            subscription_id    = param.subscription_id
            server_name        = param.name
            conn               = param.conn
            firewall_rule_name = "AllowAllWindowsAzureIps"
          }
          success_msg = "Deleted firewall rule allowing access to Azure services for PostgreSQL server ${param.title}."
          error_msg   = "Error deleting firewall rule allowing access to Azure services for PostgreSQL server ${param.title}."
        }
      }
    }
  }
}
