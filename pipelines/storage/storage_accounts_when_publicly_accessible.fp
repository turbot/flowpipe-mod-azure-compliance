locals {
  storage_accounts_when_publicly_accessible_query = <<-EOQ
    select
      concat(sa.id, ' [', sa.subscription_id, '/', sa.resource_group, ']') as title,
      sa.id as id,
      sa.name,
      sa.resource_group,
      sa.subscription_id,
      sa._ctx ->> 'connection_name' as cred
    from
      azure_storage_account as sa,
      azure_subscription as sub
    where
      sa.public_network_access = 'Enabled';
  EOQ
}

variable "storage_accounts_when_publicly_accessible_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "storage_accounts_when_publicly_accessible_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "storage_accounts_when_publicly_accessible_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "storage_accounts_when_publicly_accessible_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "disable_public_network_access"]
}

trigger "query" "detect_and_correct_storage_accounts_when_publicly_accessible" {
  title         = "Detect & correct publicly accessible Storage Accounts"
  description   = "Detect publicly accessible Storage Accounts and then disable public access."

  enabled  = var.storage_accounts_when_publicly_accessible_trigger_enabled
  schedule = var.storage_accounts_when_publicly_accessible_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_when_publicly_accessible_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_when_publicly_accessible
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_when_publicly_accessible" {
  title         = "Detect & correct publicly accessible Storage Accounts"
  description   = "Detect publicly accessible Storage Accounts and then disable public access."

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
    default     = var.storage_accounts_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_when_publicly_accessible_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_accounts_when_publicly_accessible_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_when_publicly_accessible
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

pipeline "correct_storage_accounts_when_publicly_accessible" {
  title         = "Correct publicly accessible Storage Accounts"
  description   = "Disable public access for publicly accessible Storage Accounts."

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
    default     = var.storage_accounts_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_when_publicly_accessible_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} publicly accessible Storage Account(s)."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_account_when_publicly_accessible
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

pipeline "correct_one_storage_account_when_publicly_accessible" {
  title         = "Correct publicly accessible Storage Account"
  description   = "Disable public access for a publicly accessible Storage Account."

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
    default     = var.storage_accounts_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_when_publicly_accessible_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected publicly accessible Storage Account ${param.title}."
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
            text     = "Skipped Storage Account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "disable_public_network_access" = {
          label        = "Disable public access"
          value        = "disable_public_network_access"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_storage_account_public_network_access
          pipeline_args = {
            account_name           = param.name
            resource_group         = param.resource_group
            subscription_id        = param.subscription_id
            cred                   = param.cred
            public_network_access  = false
          }
          success_msg = "Disabled public access for Storage Account ${param.title}."
          error_msg   = "Error disabling public access for Storage Account ${param.title}."
        }
      }
    }
  }
}
