
locals {
  storage_accounts_with_encryption_at_rest_using_cmk_disabled_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_storage_account
    where
      encryption_key_source = 'Microsoft.Storage';
  EOQ

}

variable "storage_accounts_with_encryption_at_rest_using_cmk_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_with_encryption_at_rest_using_cmk_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Storage"
  }
}

trigger "query" "detect_and_correct_storage_accounts_with_encryption_at_rest_using_cmk_disabled" {
  title       = "Detect & correct Storage accounts with encryption at rest using CMK disabled"
  description = "Detect Storage accounts with encryption at rest using CMK disabled."

  tags = local.storage_common_tags

  enabled  = var.storage_accounts_with_encryption_at_rest_using_cmk_disabled_trigger_enabled
  schedule = var.storage_accounts_with_encryption_at_rest_using_cmk_disabled_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_with_encryption_at_rest_using_cmk_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_with_encryption_at_rest_using_cmk_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_with_encryption_at_rest_using_cmk_disabled" {
  title       = "Detect & correct Storage accounts with encryption at rest using CMK disabled"
  description = "Detect Storage accounts with encryption at rest using CMK disabled."

  tags = local.storage_common_tags

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
    sql      = local.storage_accounts_with_encryption_at_rest_using_cmk_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_with_encryption_at_rest_using_cmk_disabled
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_storage_accounts_with_encryption_at_rest_using_cmk_disabled" {
  title       = "Correct Storage accounts with encryption at rest using CMK disabled"
  description = "Executes corrective actions on Storage accounts with encryption at rest using CMK disabled."
  tags = merge(local.storage_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      conn            = string
    }))
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
    text     = "Detected ${length(param.items)} Storage account(s) with encryption at rest using CMK disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Storage accoun ${each.value.title} with encryption at rest using CMK disabled."
  }
}
