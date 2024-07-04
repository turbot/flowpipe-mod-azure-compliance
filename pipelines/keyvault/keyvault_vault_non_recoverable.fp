locals {
  keyvault_vault_non_recoverable_query = <<-EOQ
    select
      concat(vault.id, ' [', vault.resource_group, '/', vault.subscription_id, ']') as title,
      vault.id as id,
      vault.name,
      vault.resource_group,
      vault.subscription_id,
      vault._ctx ->> 'connection_name' as cred
    from
      azure_key_vault as vault,
      azure_subscription as sub
    where
      sub.subscription_id = vault.subscription_id
      and not (soft_delete_enabled and purge_protection_enabled);
  EOQ
}

trigger "query" "detect_and_correct_keyvault_vault_non_recoverable" {
  title         = "Detect & correct non-recoverable Key Vaults"
  description   = "Detects non-recoverable Key Vaults and runs your chosen action."
  // documentation = file("./keyvault/docs/detect_and_correct_keyvault_vault_non_recoverable_trigger.md")
  tags          = merge(local.keyvault_common_tags, { class = "security" })

  enabled  = var.keyvault_vault_non_recoverable_trigger_enabled
  schedule = var.keyvault_vault_non_recoverable_trigger_schedule
  database = var.database
  sql      = local.keyvault_vault_non_recoverable_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_vault_non_recoverable
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_vault_non_recoverable" {
  title         = "Detect & correct non-recoverable Key Vaults"
  description   = "Detects non-recoverable Key Vaults and runs your chosen action."
  // documentation = file("./keyvault/docs/detect_and_correct_keyvault_vault_non_recoverable.md")
  tags          = merge(local.keyvault_common_tags, { class = "security", type = "featured" })

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
    default     = var.keyvault_vault_non_recoverable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vault_non_recoverable_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.keyvault_vault_non_recoverable_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_vault_non_recoverable
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

pipeline "correct_keyvault_vault_non_recoverable" {
  title         = "Correct non-recoverable Key Vaults"
  description   = "Runs corrective action on a collection of non-recoverable Key Vaults."
  // documentation = file("./keyvault/docs/correct_keyvault_vault_non_recoverable.md")
  tags          = merge(local.keyvault_common_tags, { class = "security" })

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
    default     = var.keyvault_vault_non_recoverable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vault_non_recoverable_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} non-recoverable Key Vaults."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_keyvault_vault_non_recoverable
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

pipeline "correct_one_keyvault_vault_non_recoverable" {
  title         = "Correct one non-recoverable Key Vault"
  description   = "Runs corrective action on a single non-recoverable Key Vault."
  // documentation = file("./keyvault/docs/correct_one_keyvault_vault_non_recoverable.md")
  tags          = merge(local.keyvault_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Key Vault."
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
    default     = var.keyvault_vault_non_recoverable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vault_non_recoverable_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Key Vault ${param.title} as non-recoverable."
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
            text     = "Skipped Key Vault ${param.title} as non-recoverable."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_purge_protection" = {
          label        = "Enable Soft Delete and Purge Protection"
          value        = "enable_purge_protection"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_azure_key_vault_purge_protection
          pipeline_args = {
            resource_group        = param.resource_group
            subscription_id       = param.subscription_id
            vault_name            = param.name
            cred                  = param.cred
            enable_purge_protection = true
          }
          success_msg = "Enabled soft delete and purge protection for Key Vault ${param.title}."
          error_msg   = "Error enabling soft delete and purge protection for Key Vault ${param.title}."
        }
      }
    }
  }
}

variable "keyvault_vault_non_recoverable_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "keyvault_vault_non_recoverable_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "keyvault_vault_non_recoverable_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "keyvault_vault_non_recoverable_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_purge_protection"]
}
