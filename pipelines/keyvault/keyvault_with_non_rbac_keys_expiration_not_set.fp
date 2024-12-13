locals {
  keyvault_with_non_rbac_keys_expiration_not_set_query = <<-EOQ
    with non_rbac_vault as (
      select
        name
      from
        azure_key_vault
      where
        not enable_rbac_authorization
    )
    select
      concat(kvk.id, ' [', kvk.subscription_id, '/', kvk.resource_group, ']') as title,
      kvk.id as id,
      kvk.name,
      kvk.subscription_id,
      kvk.vault_name as vault_name,
      kvk._ctx ->> 'connection_name' as conn
    from
      azure_key_vault_key kvk
      left join non_rbac_vault as v on v.name = kvk.vault_name
    where
      enabled
      and expires_at is null
      and v.name is not null;
  EOQ

  keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions_enum = ["skip", "set_key_expiration"]
  keyvault_with_non_rbac_keys_expiration_not_set_default_action_enum = ["notify", "skip", "set_key_expiration"]
}

variable "keyvault_with_non_rbac_keys_expiration_not_set_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_with_non_rbac_keys_expiration_not_set_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_with_non_rbac_keys_expiration_not_set_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "set_key_expiration"]

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_with_non_rbac_keys_expiration_not_set_expiration_date" {
  type        = string
  description = "The expiry date and time for the key in the format Y-m-d'T'H:M:S'Z'."
  default     = " " // Add key expiration date here

  tags = {
    folder = "Advanced/KeyVault"
  }
}

trigger "query" "detect_and_correct_keyvault_with_non_rbac_keys_expiration_not_set" {
  title         = "Detect & correct Key Vaults with non-RBAC keys without expiration date"
  description   = "Detects Key Vaults with non-RBAC keys that do not have an expiration date set and then set expiration date."
  tags          = local.keyvault_common_tags

  enabled  = var.keyvault_with_non_rbac_keys_expiration_not_set_trigger_enabled
  schedule = var.keyvault_with_non_rbac_keys_expiration_not_set_trigger_schedule
  database = var.database
  sql      = local.keyvault_with_non_rbac_keys_expiration_not_set_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_with_non_rbac_keys_expiration_not_set
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_with_non_rbac_keys_expiration_not_set" {
  title         = "Detect & correct Key Vaults with non-RBAC keys without expiration date"
  description   = "Detects Key Vaults with non-RBAC keys that do not have an expiration date set and then set expiration date."
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
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_default_action
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions_enum
  }

  param "expiration_date" {
    type        = string
    description = "The expiry date and time for the key in the format Y-m-d'T'H:M:S'Z'."
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_expiration_date
  }

  step "query" "detect" {
    database = param.database
    sql      = local.keyvault_with_non_rbac_keys_expiration_not_set_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_with_non_rbac_keys_expiration_not_set
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      expiration_date    = param.expiration_date
    }
  }
}

pipeline "correct_keyvault_with_non_rbac_keys_expiration_not_set" {
  title         = "Correct Key Vaults with non-RBAC keys without expiration date"
  description   = "Runs corrective action on a collection of Key Vaults with non-RBAC keys without expiration date."
  tags          = merge(local.keyvault_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      vault_name      = string
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
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_default_action
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions_enum
  }

  param "expiration_date" {
    type        = string
    description = "The expiry date and time for the key in the format Y-m-d'T'H:M:S'Z'."
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_expiration_date
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Key Vaults with non-RBAC keys without expiration date."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_keyvault_with_non_rbac_key_expiration_not_set
    args = {
      title              = each.value.title
      name               = each.value.name
      vault_name         = each.value.vault_name
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      expiration_date    = param.expiration_date
    }
  }
}

pipeline "correct_one_keyvault_with_non_rbac_key_expiration_not_set" {
  title         = "Correct one Key Vault with non-RBAC key without expiration date"
  description   = "Runs corrective action on a single Key Vault with non-RBAC key without expiration date."
  tags          = merge(local.keyvault_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Key Vault key."
  }

  param "vault_name" {
    type        = string
    description = "The key vault name."
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
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_default_action
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions
    enum        = local.keyvault_with_non_rbac_keys_expiration_not_set_enabled_actions_enum
  }

  param "expiration_date" {
    type        = string
    description = "The expiry date and time for the key in the format Y-m-d'T'H:M:S'Z'."
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Key Vault key ${param.title} without expiration date."
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
            text     = "Skipped Key Vault key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "set_key_expiration" = {
          label        = "Set key expiration"
          value        = "set_key_expiration"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_key_vault_key_attributes
          pipeline_args = {
            vault_name      = param.vault_name
            key_name        = param.name
            subscription_id = param.subscription_id
            expires         = param.expiration_date
            conn            = param.conn
          }
          success_msg = "Set expiration date for Key Vault key ${param.title}."
          error_msg   = "Error setting expiration date for Key Vault key ${param.title}."
        }
      }
    }
  }
}
