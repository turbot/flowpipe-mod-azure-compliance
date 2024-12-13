locals {
  keyvault_vaults_with_logging_disabled_query = <<-EOQ
    with logging_details as (
      select
        name as key_vault_name
      from
        azure_key_vault,
        jsonb_array_elements(diagnostic_settings) setting,
        jsonb_array_elements(setting -> 'properties' -> 'logs') log
      where
        diagnostic_settings is not null
        and setting -> 'properties' ->> 'storageAccountId' <> ''
        and (log ->> 'enabled') :: boolean
        and log ->> 'category' = 'AuditEvent'
        and (log -> 'retentionPolicy') :: JSONB ? 'days'
    )
    select
      concat(v.id, ' [', v.subscription_id, '/', v.resource_group, ']') as title,
      v.id as id,
      v.name,
      v.resource_group,
      v.subscription_id,
      v._ctx ->> 'connection_name' as conn
    from
      azure_key_vault v
      left join logging_details l on l.key_vault_name = v.name
    where
      v.diagnostic_settings is null
      or l.key_vault_name not like concat('%', v.name, '%');
  EOQ
}

variable "keyvault_vaults_with_logging_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/KeyVault"
  }
}

variable "keyvault_vaults_with_logging_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/KeyVault"
  }
}

trigger "query" "detect_and_correct_keyvault_vaults_with_logging_disabled" {
  title         = "Detect & correct Key Vaults with logging disabled"
  description   = "Detect key vaults with logging disabled."
  tags          = local.keyvault_common_tags

  enabled  = var.keyvault_vaults_with_logging_disabled_trigger_enabled
  schedule = var.keyvault_vaults_with_logging_disabled_trigger_schedule
  database = var.database
  sql      = local.keyvault_vaults_with_logging_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_keyvault_vaults_with_logging_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_keyvault_vaults_with_logging_disabled" {
  title         = "Detect & correct Key Vaults with logging disabled"
  description   = "Detect key vaults with logging disabled."
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
    sql      = local.keyvault_vaults_with_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_keyvault_vaults_with_logging_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_keyvault_vaults_with_logging_disabled" {
  title         = "Correct Key Vaults with logging disabled"
  description   = "Send notifications for key vaults with logging disabled."
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
    text     = "Detected ${length(param.items)} key vault(s) with logging disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected key vault ${each.value.title} with logging disabled."
  }
}
