locals {
  keyvault_vaults_without_private_link_query = <<-EOQ
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
      private_endpoint_connections is null
      or ( not private_endpoint_connections @> '[{"PrivateLinkServiceConnectionStateStatus": "Approved"}]');
  EOQ
}

variable "keyvault_vaults_without_private_link_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_vaults_without_private_link_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/KeyVault"
  }
}

trigger "query" "detect_and_correct_keyvault_vaults_without_private_link" {
  title         = "Detect & correct Key Vaults without a private link"
  description   = "Detect Key Vaults without a private link."
  tags          = local.keyvault_common_tags

  enabled  = var.keyvault_vaults_without_private_link_trigger_enabled
  schedule = var.keyvault_vaults_without_private_link_trigger_schedule
  database = var.database
  sql      = local.keyvault_vaults_without_private_link_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_vaults_without_private_link
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_vaults_without_private_link" {
  title         = "Detect & correct Key Vaults without a private link"
  description   = "Detect Key Vaults without a private link."
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
    sql      = local.keyvault_vaults_without_private_link_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_vaults_without_private_link
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_keyvault_vaults_without_private_link" {
  title         = "Correct Key Vaults without a private link"
  description   = "Send notifications for Key Vaults without a private link."
  tags         = merge(local.keyvault_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Key Vault(s) without private link."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Key Vault ${each.value.title} without private link."
  }
}
