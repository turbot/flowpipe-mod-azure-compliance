locals {
  storage_accounts_with_table_service_logging_disabled_query = <<-EOQ
    with get_access_key as (
      select
        distinct on (id) id,
        k ->> 'Value' as access_key
      from
        azure_storage_account,
        jsonb_array_elements(access_keys) as k
      order by
        id
    )
    select
      distinct concat(sa.id, ' [', sa.resource_group, '/', sa.subscription_id, ']') as title,
      sa.id as id,
      k.access_key as access_key,
      sa.name,
      sa.subscription_id,
      sa._ctx ->> 'connection_name' as conn
    from
      azure_storage_account as sa,
      get_access_key as k,
      azure_subscription as sub
    where
      sub.subscription_id = sa.subscription_id
      and k.id = sa.id
      and (
        not table_logging_write
        or not table_logging_read
        or not table_logging_delete
      )
  EOQ

  storage_accounts_with_table_service_logging_disabled_enabled_actions_enum = ["skip", "enable_table_service_logging"]
  storage_accounts_with_table_service_logging_disabled_default_action_enum = ["notify", "skip", "enable_table_service_logging"]
}

variable "storage_accounts_with_table_service_logging_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_with_table_service_logging_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_with_table_service_logging_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_accounts_with_table_service_logging_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_table_service_logging"]

  tags = {
    folder = "Advanced/Storage"
  }
}

trigger "query" "detect_and_correct_storage_accounts_with_table_service_logging_disabled" {
  title         = "Detect & correct Storage Accounts with table service logging disabled"
  description   = "Detect Storage Accounts with table service logging disabled and then enable table service logging."
  tags          = local.storage_common_tags

  enabled  = var.storage_accounts_with_table_service_logging_disabled_trigger_enabled
  schedule = var.storage_accounts_with_table_service_logging_disabled_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_with_table_service_logging_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_with_table_service_logging_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_with_table_service_logging_disabled" {
  title         = "Detect & correct Storage Accounts with table service logging disabled"
  description   = "Detect Storage Accounts with table service logging disabled and then enable table service logging."
  tags          = merge(local.storage_common_tags, { recommended = "true" })

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
    default     = var.storage_accounts_with_table_service_logging_disabled_default_action
    enum        = local.storage_accounts_with_table_service_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_table_service_logging_disabled_enabled_actions
    enum        = local.storage_accounts_with_table_service_logging_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_accounts_with_table_service_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_with_table_service_logging_disabled
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

pipeline "correct_storage_accounts_with_table_service_logging_disabled" {
  title         = "Correct Storage Accounts with table service logging disabled"
  description   = "Enable table service logging for Storage Accounts with table service logging disabled."
  tags          = merge(local.storage_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      subscription_id = string
      access_key      = string
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
    default     = var.storage_accounts_with_table_service_logging_disabled_default_action
    enum        = local.storage_accounts_with_table_service_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_table_service_logging_disabled_enabled_actions
    enum        = local.storage_accounts_with_table_service_logging_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage Account(s) with table service logging disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_account_with_table_service_logging_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      subscription_id    = each.value.subscription_id
      access_key         = each.value.access_key
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_storage_account_with_table_service_logging_disabled" {
  title         = "Correct Storage Account with table service logging disabled"
  description   = "Enable table service logging for a Storage Account with table service logging disabled."
  tags          = merge(local.storage_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Storage Account."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "access_key" {
    type        = string
    description = "The access key of the storage account."
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
    default     = var.storage_accounts_with_table_service_logging_disabled_default_action
    enum        = local.storage_accounts_with_table_service_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_with_table_service_logging_disabled_enabled_actions
    enum        = local.storage_accounts_with_table_service_logging_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Storage Account ${param.title} with table service logging disabled."
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
            text     = "Skipped Storage Account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_table_service_logging" = {
          label        = "Enable table service logging"
          value        = "enable_table_service_logging"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_storage_account_logging
          pipeline_args = {
            account_name     = param.name
            subscription_id  = param.subscription_id
            access_key       = param.access_key
            conn             = param.conn
            services         = "t"
            log              = "rwd"
            retention        = 90
          }
          success_msg = "Enabled table service logging for Storage Account ${param.title}."
          error_msg   = "Error enabling table service logging for Storage Account ${param.title}."
        }
      }
    }
  }
}

