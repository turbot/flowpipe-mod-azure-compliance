
locals {
  monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query = <<-EOQ
    select
      concat(a.id, ' [', a.subscription_id, '/', a.resource_group, ']') as title,
      a.id as id,
      a.name,
      a.resource_group,
      a.subscription_id,
      a._ctx ->> 'connection_name' as conn
    from
      azure_storage_container c,
      azure_storage_account a
		where
      c.name = 'insights-activity-logs'
      and c.account_name = a.name
      and a.encryption_key_source <> 'Microsoft.Keyvault';
  EOQ

  monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action_enum  = ["notify", "skip", "encrypt_storage_account_with_cmk"]
  monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions_enum = ["skip", "encrypt_storage_account_with_cmk"]
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "encrypt_storage_account_with_cmk"]

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "encrypt_storage_account_with_cmk"]
  enum        = ["skip", "encrypt_storage_account_with_cmk"]

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_key_vault_uri" {
  type        = string
  description = "Specifies the URI of the Key Vault where the encryption key is stored."
  default     = " " // Add your key vault URI here.

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_version" {
  type        = string
  description = "Specifies the version of the encryption key in Key Vault. Leave blank for the latest version."
  default     = " " // Add your key version here.

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_name" {
  type        = string
  description = "Specifies the name of the encryption key in Key Vault."
  default     = " " // Add your key name here.

  tags = {
    folder = "Advanced/Storage"
  }
}

trigger "query" "detect_and_correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Detect & correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Detect Storage account containers insights activity logs not encrypted with CMK and then enable encryption using CMK."

  tags = local.storage_common_tags

  enabled  = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_enabled
  schedule = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_trigger_schedule
  database = var.database
  sql      = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Detect & correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Detect Storage containers insights activity logs not encrypted with CMK and then enable encryption using CMK."

  tags = local.storage_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "encryption_key_name" {
    type        = string
    description = "Specifies the name of the encryption key in Key Vault."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_name
  }

  param "encryption_key_version" {
    type        = string
    description = "Specifies the version of the encryption key in Key Vault. Leave blank for the latest version."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_version
  }

  param "key_vault_uri" {
    type        = string
    description = "Specifies the URI of the Key Vault where the encryption key is stored."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_key_vault_uri
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
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk
    args = {
      items                   = step.query.detect.rows
      encryption_key_name     = param.encryption_key_name
      encryption_key_version  = param.encryption_key_version
      key_vault_uri           = param.key_vault_uri
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
    }
  }
}

pipeline "correct_monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Correct Storage account containers insights activity logs not encrypted with CMK"
  description = "Executes corrective actions on Storage account containers insights activity logs not encrypted with CMK."
  tags = merge(local.storage_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      subscription_id = string
      name            = string
      resource_group  = string
      conn            = string
    }))
  }

  param "encryption_key_name" {
    type        = string
    description = "Specifies the name of the encryption key in Key Vault."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_name
  }

  param "encryption_key_version" {
    type        = string
    description = "Specifies the version of the encryption key in Key Vault. Leave blank for the latest version."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_version
  }

  param "key_vault_uri" {
    type        = string
    description = "Specifies the URI of the Key Vault where the encryption key is stored."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_key_vault_uri
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
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage account container(s) insights activity logs not encrypted with CMK."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_monitor_storage_container_insights_activity_logs_not_encrypted_with_cmk
    args = {
      title                   = each.value.title
      name                    = each.value.name
      resource_group          = each.value.resource_group
      subscription_id         = each.value.subscription_id
      conn                    = connection.azure[each.value.conn]
      encryption_key_name     = param.encryption_key_name
      encryption_key_version  = param.encryption_key_version
      key_vault_uri           = param.key_vault_uri
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
    }
  }
}

pipeline "correct_one_monitor_storage_container_insights_activity_logs_not_encrypted_with_cmk" {
  title       = "Correct one Storage account container insights activity logs not encrypted with CMK"
  description = "Runs corrective action on a single Storage account container insights activity logs not encrypted with CMK."

  tags = merge(local.storage_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Storage Account."
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
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions
    enum        = local.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "encryption_key_name" {
    type        = string
    description = "Specifies the name of the encryption key in Key Vault."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_name
  }

  param "encryption_key_version" {
    type        = string
    description = "Specifies the version of the encryption key in Key Vault. Leave blank for the latest version."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_encryption_key_version
  }

  param "key_vault_uri" {
    type        = string
    description = "Specifies the URI of the Key Vault where the encryption key is stored."
    default     = var.monitor_storage_containers_insights_activity_logs_not_encrypted_with_cmk_key_vault_uri
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Storage account containers insights activity logs ${param.title}  not encrypted with CMK"
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
            text     = "Skipped Storage account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "encrypt_storage_account_with_cmk" = {
          label        = "Encrypt storage account with CMK"
          value        = "encrypt_storage_account_with_cmk"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.encrypt_storage_account
          pipeline_args = {
            subscription_id        = param.subscription_id
            resource_group         = param.resource_group
            account_name           = param.name
            encryption_key_name    = param.encryption_key_name
            encryption_key_version = param.encryption_key_version
            key_vault_uri          = param.key_vault_uri
            conn                   = param.conn
          }
          success_msg = "Encrypted Storage account ${param.title} with CMK."
          error_msg   = "Error encrypting Storage account ${param.title} with CMK."
        }
      }
    }
  }
}