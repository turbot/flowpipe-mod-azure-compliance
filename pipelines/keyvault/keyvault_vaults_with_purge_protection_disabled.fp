locals {
  keyvault_vaults_with_purge_protection_disabled_query = <<-EOQ
    select
      concat(vault.id, ' [', vault.subscription_id, '/', vault.resource_group, ']') as title,
      vault.id as id,
      vault.name,
      vault.resource_group,
      vault.subscription_id,
      vault._ctx ->> 'connection_name' as conn
    from
      azure_key_vault as vault
    where
      not (soft_delete_enabled and purge_protection_enabled);
  EOQ

  keyvault_vaults_with_purge_protection_disabled_enabled_actions_enum = ["skip", "enable_purge_protection"]
  keyvault_vaults_with_purge_protection_disabled_default_action_enum = ["notify", "skip", "enable_purge_protection"]
}

variable "keyvault_vaults_with_purge_protection_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_vaults_with_purge_protection_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_vaults_with_purge_protection_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_vaults_with_purge_protection_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_purge_protection"]

  tags = {
    folder = "Advanced/KeyVault"
  }
}

trigger "query" "detect_and_correct_keyvault_vaults_with_purge_protection_disabled" {
  title         = "Detect & correct Key Vaults with purge protection disabled"
  description   = "Detect key vaults with purge protection disabled and then enable purge protection."
  tags          = local.keyvault_common_tags

  enabled  = var.keyvault_vaults_with_purge_protection_disabled_trigger_enabled
  schedule = var.keyvault_vaults_with_purge_protection_disabled_trigger_schedule
  database = var.database
  sql      = local.keyvault_vaults_with_purge_protection_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_vaults_with_purge_protection_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_vaults_with_purge_protection_disabled" {
  title         = "Detect & correct Key Vaults with purge protection disabled"
  description   = "Detect key vaults with purge protection disabled and then enable purge protection."
  tags          = local.keyvault_common_tags

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
    default     = var.keyvault_vaults_with_purge_protection_disabled_default_action
    enum        = local.keyvault_vaults_with_purge_protection_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vaults_with_purge_protection_disabled_enabled_actions
    enum        = local.keyvault_vaults_with_purge_protection_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.keyvault_vaults_with_purge_protection_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_vaults_with_purge_protection_disabled
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

pipeline "correct_keyvault_vaults_with_purge_protection_disabled" {
  title         = "Correct Key Vaults with purge protection disabled"
  description   = "Enable purge protection on a collection of key vaults with purge protection disabled."
  tags          = merge(local.keyvault_common_tags, { folder = "Internal" })

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
    default     = var.keyvault_vaults_with_purge_protection_disabled_default_action
    enum        = local.keyvault_vaults_with_purge_protection_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vaults_with_purge_protection_disabled_enabled_actions
    enum        = local.keyvault_vaults_with_purge_protection_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} non-recoverable Key Vaults."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_keyvault_vault_non_recoverable
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

pipeline "correct_one_keyvault_vault_non_recoverable" {
  title         = "Correct one Key Vault with purge protection disabled"
  description   = "Enable purge protection on a key vault with purge protection disabled."
  tags          = merge(local.keyvault_common_tags, { folder = "Internal" })

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
    default     = var.keyvault_vaults_with_purge_protection_disabled_default_action
    enum        = local.keyvault_vaults_with_purge_protection_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_vaults_with_purge_protection_disabled_enabled_actions
    enum        = local.keyvault_vaults_with_purge_protection_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected key vault ${param.title} as non-recoverable."
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
            text     = "Skipped key vault ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_purge_protection" = {
          label        = "Enable purge protection"
          value        = "enable_purge_protection"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_azure_key_vault_purge_protection
          pipeline_args = {
            resource_group          = param.resource_group
            subscription_id         = param.subscription_id
            vault_name              = param.name
            conn                    = param.conn
            enable_purge_protection = true
          }
          success_msg = "Enabled purge protection for key vault ${param.title}."
          error_msg   = "Error enabling purge protection for key vault ${param.title}."
        }
      }
    }
  }
}
