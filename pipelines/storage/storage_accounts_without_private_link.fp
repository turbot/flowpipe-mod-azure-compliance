locals {
  storage_accounts_without_private_link_query = <<-EOQ
    with storage_account_connection as (
      select
        distinct a.id
      from
        azure_storage_account as a,
        jsonb_array_elements(private_endpoint_connections) as connection
      where
        connection -> 'properties' -> 'privateLinkServiceConnectionState' ->> 'status' = 'Approved'
    )
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
      id not in (select id from storage_account_connection);
  EOQ
}

variable "storage_accounts_without_private_link_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_without_private_link_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Storage"
  }
}

trigger "query" "detect_and_correct_storage_accounts_without_private_link" {
  title         = "Detect & correct Storage Accounts not using private link"
  description   = "Detects Storage Accounts not using private link."
  tags          = local.storage_common_tags

  enabled  = var.storage_accounts_without_private_link_trigger_enabled
  schedule = var.storage_accounts_without_private_link_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_without_private_link_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_without_private_link
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_without_private_link" {
  title         = "Detect & correct Storage Accounts not using private link"
  description   = "Detects Storage Accounts not using private link."
  tags          = local.storage_common_tags

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
    sql      = local.storage_accounts_without_private_link_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_without_private_link
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_storage_accounts_without_private_link" {
  title         = "Correct Storage Accounts not using private link"
  description   = "Send notifications for Storage Accounts not using private link."
  tags         = merge(local.storage_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Storage Account(s) without private link."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Storage Account ${each.value.title} without private link."
  }
}
