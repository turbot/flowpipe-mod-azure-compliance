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
      kvs._ctx ->> 'connection_name' as conn
    from
      azure_key_vault_secret kvs
      left join non_rbac_vault as v on v.name = kvs.vault_name
    where
      kvs.enabled and kvs.expires_at is null
      and v.name is not null;
  EOQ
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_with_non_rbac_secrets_expiration_not_set_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/KeyVault"
  }
}

trigger "query" "detect_and_correct_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Detect & correct Key Vaults with non-RBAC secrets without expiration date"
  description   = "Detect Key Vaults with non-RBAC secrets that do not have an expiration date set and then set expiration date."
  tags          = local.keyvault_common_tags

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
  description   = "Detect Key Vaults with non-RBAC secrets that do not have an expiration date set and then set expiration date."
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
    }
  }
}

pipeline "correct_keyvault_with_non_rbac_secrets_expiration_not_set" {
  title         = "Correct Key Vaults with non-RBAC secrets without expiration date"
  description   = "Runs corrective action on a collection of Key Vaults with non-RBAC secrets without expiration date."
  tags          = merge(local.keyvault_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
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

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Key Vaults with non-RBAC secrets without expiration date."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Key Vault ${each.value.title} with non-RBAC secrets without expiration date."
  }
}

