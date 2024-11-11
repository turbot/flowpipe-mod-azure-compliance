locals {
  storage_accounts_with_trusted_microsoft_services_disabled_query = <<-EOQ
    select
      concat(sa.id, ' [', sa.resource_group, '/', sa.subscription_id, ']') as title,
      sa.id as id,
      sa.name,
      sa.resource_group,
      sa.subscription_id,
      sa._ctx ->> 'connection_name' as conn
    from
      azure_storage_account as sa,
      azure_subscription as sub
    where
      sub.subscription_id = sa.subscription_id
      and network_rule_bypass not like '%AzureServices%';
  EOQ

  storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions_enum = ["skip", "enable_trusted_microsoft_services"]
  storage_accounts_with_trusted_microsoft_services_disabled_default_action_enum = ["notify", "skip", "enable_trusted_microsoft_services"]
}

variable "storage_accounts_with_trusted_microsoft_services_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "storage_accounts_with_trusted_microsoft_services_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "storage_accounts_with_trusted_microsoft_services_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_trusted_microsoft_services"]
}

trigger "query" "detect_and_correct_storage_accounts_with_trusted_microsoft_services_disabled" {
  title         = "Detect & correct Storage Accounts with trusted Microsoft services access disabled"
  description   = "Detect Storage Accounts with trusted Microsoft services access disabled and then enable trusted Microsoft services."

  enabled  = var.storage_accounts_with_trusted_microsoft_services_disabled_trigger_enabled
  schedule = var.storage_accounts_with_trusted_microsoft_services_disabled_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_with_trusted_microsoft_services_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_with_trusted_microsoft_services_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_with_trusted_microsoft_services_disabled" {
  title         = "Detect & correct Storage Accounts with trusted Microsoft services access disabled"
  description   = "Detect Storage Accounts with trusted Microsoft services access disabled and then enable trusted Microsoft services."

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
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_default_action
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_accounts_with_trusted_microsoft_services_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_with_trusted_microsoft_services_disabled
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

pipeline "correct_storage_accounts_with_trusted_microsoft_services_disabled" {
  title         = "Correct Storage Accounts with trusted Microsoft services access disabled"
  description   = "Enable trusted Microsoft services for Storage Accounts with trusted Microsoft services access disabled."

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
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_default_action
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage Account(s) with trusted Microsoft services access disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_account_with_trusted_microsoft_services_disabled
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

pipeline "correct_one_storage_account_with_trusted_microsoft_services_disabled" {
  title         = "Correct Storage Account with trusted Microsoft services access disabled"
  description   = "Enable trusted Microsoft services for a Storage Account with trusted Microsoft services access disabled."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Storage Account."
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
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_default_action
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions
    enum        = local.storage_accounts_with_trusted_microsoft_services_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Storage Account ${param.title} with trusted Microsoft services access disabled."
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
            text     = "Skipped Storage Account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_trusted_microsoft_services" = {
          label        = "Enable trusted microsoft services"
          value        = "enable_trusted_microsoft_services"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_storage_account_bypass_azure_services
          pipeline_args = {
            account_name                      = param.name
            resource_group                    = param.resource_group
            subscription_id                   = param.subscription_id
            conn                              = param.conn
          }
          success_msg = "Enabled trusted Microsoft services access for Storage Account ${param.title}."
          error_msg   = "Error enabling trusted Microsoft services access for Storage Account ${param.title}."
        }
      }
    }
  }
}

