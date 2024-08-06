locals {
  storage_accounts_table_service_logging_disabled_query = <<-EOQ
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
      sa._ctx ->> 'connection_name' as cred
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
}

trigger "query" "detect_and_correct_storage_accounts_table_service_logging_disabled" {
  title         = "Detect & correct Storage Accounts with table service logging disabled"
  description   = "Detects Storage Accounts with table service logging disabled and runs your chosen action."
  tags          = merge(local.storage_common_tags, { class = "unused" })

  enabled  = var.storage_accounts_table_service_logging_disabled_trigger_enabled
  schedule = var.storage_accounts_table_service_logging_disabled_trigger_schedule
  database = var.database
  sql      = local.storage_accounts_table_service_logging_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_storage_accounts_table_service_logging_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_accounts_table_service_logging_disabled" {
  title         = "Detect & correct Storage Accounts with table service logging disabled"
  description   = "Detects Storage Accounts with table service logging disabled and runs your chosen action."
  tags          = merge(local.storage_common_tags, { class = "unused", type = "featured" })

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
    default     = var.storage_accounts_table_service_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_table_service_logging_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_accounts_table_service_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_accounts_table_service_logging_disabled
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

pipeline "correct_storage_accounts_table_service_logging_disabled" {
  title         = "Correct Storage Accounts with table service logging disabled"
  description   = "Runs corrective action on a collection of Storage Accounts with table service logging disabled."
  tags          = merge(local.storage_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      subscription_id = string
      access_key      = string
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
    default     = var.storage_accounts_table_service_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_table_service_logging_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Storage Accounts with table service logging disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_accounts_table_service_logging_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      subscription_id    = each.value.subscription_id
      access_key         = each.value.access_key
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_storage_accounts_table_service_logging_disabled" {
  title         = "Correct one Storage Account with table service logging disabled"
  description   = "Runs corrective action on a single Storage Account with table service logging disabled."
  tags          = merge(local.storage_common_tags, { class = "unused" })

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
    default     = var.storage_accounts_table_service_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_accounts_table_service_logging_disabled_enabled_actions
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
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped Storage Account ${param.title} with table service logging disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_table_service_logging" = {
          label        = "Enable Table Service Logging"
          value        = "enable_table_service_logging"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_storage_account_logging
          pipeline_args = {
            account_name     = param.name
            subscription_id  = param.subscription_id
            access_key       = param.access_key
            cred             = param.cred
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

variable "storage_accounts_table_service_logging_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "storage_accounts_table_service_logging_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "storage_accounts_table_service_logging_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "storage_accounts_table_service_logging_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_table_service_logging"]
}
