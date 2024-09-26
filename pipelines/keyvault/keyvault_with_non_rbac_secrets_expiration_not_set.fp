locals {
  keyvault_with_non_rbac_secrets_expiration_not_set_query = <<-EOQ
    with non_rbac_vault as (
      select
        name
      from
        azure_key_vault
      where
        not enable_rbac_authorization
    )
    select
      concat(kvs.id, ' [', kvs.subscription_id, '/', kvs.resource_group, ']') as title,
      kvs.id as id,
      kvs.name,
      kvs.subscription_id,
      kvs.vault_name as vault_name,
      kvs._ctx ->> 'connection_name' as cred
    from
      azure_key_vault_secret kvs
      left join non_rbac_vault as v on v.name = kvs.vault_name
      left join azure_subscription sub on sub.subscription_id = kvs.subscription_id
    where
      kvs.enabled and kvs.expires_at is null;
  EOQ
}

locals {
  non_rbac_secrets_expiration_date = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "2160h"))
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "set_secret_expiration"]
}

trigger "query" "detect_and_correct_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Detect & correct Key Vaults with non-RBAC secrets without expiration date"
  description   = "Detects Key Vaults with non-RBAC secrets that do not have an expiration date set and runs your chosen action."

  enabled  = var.keyvault_with_non_rbac_secrets_expiration_not_set_trigger_enabled
  schedule = var.keyvault_with_non_rbac_secrets_expiration_not_set_trigger_schedule
  database = var.database
  sql      = local.keyvault_with_non_rbac_secrets_expiration_not_set_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_with_non_rbac_secrets_expiration_not_set
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Detect & correct Key Vaults with non-RBAC secrets without expiration date"
  description   = "Detects Key Vaults with non-RBAC secrets that do not have an expiration date set and runs your chosen action."

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
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.keyvault_with_non_rbac_secrets_expiration_not_set_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_with_non_rbac_secrets_expiration_not_set
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

pipeline "correct_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Correct Key Vaults with non-RBAC secrets without expiration date"
  description   = "Runs corrective action on a collection of Key Vaults with non-RBAC secrets without expiration date."

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      vault_name      = string
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
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Key Vaults with non-RBAC secrets without expiration date."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_keyvault_with_non_rbac_secrets_expiration_not_set
    args = {
      title              = each.value.title
      name               = each.value.name
      vault_name         = each.value.vault_name
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

pipeline "correct_one_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Correct one Key Vault with non-RBAC secret without expiration date"
  description   = "Runs corrective action on a single Key Vault with non-RBAC secret without expiration date."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Key Vault secret."
  }

  param "vault_name" {
    type        = string
    description = "The key vault name."
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
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.keyvault_with_non_rbac_secrets_expiration_not_set_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Key Vault secret ${param.title} without expiration date."
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
            text     = "Skipped Key Vault secret ${param.title} without expiration date."
          }
          success_msg = ""
          error_msg   = ""
        },
        "set_secret_expiration" = {
          label        = "Set Secret Expiration"
          value        = "set_secret_expiration"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_set_key_vault_secret_attributes
          pipeline_args = {
            vault_name      = param.vault_name
            secret_name     = param.name
            subscription_id = param.subscription_id
            expires         = local.non_rbac_secrets_expiration_date
            cred            = param.cred
          }
          success_msg = "Set expiration date for Key Vault secret ${param.title}."
          error_msg   = "Error setting expiration date for Key Vault secret ${param.title}."
        }
      }
    }
  }
}
