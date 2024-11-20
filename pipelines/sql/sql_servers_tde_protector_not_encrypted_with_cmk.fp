locals {
  sql_servers_tde_protector_not_encrypted_with_cmk_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
			name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_sql_server,
      jsonb_array_elements(encryption_protector) encryption
    where
     	encryption ->> 'kind' = 'servicemanaged';
  EOQ

  sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions_enum = ["skip", "encrypt_tde_with_cmk"]
  sql_servers_tde_protector_not_encrypted_with_cmk_default_action_enum = ["notify", "skip", "encrypt_tde_with_cmk"]
}

variable "sql_servers_tde_protector_not_encrypted_with_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_tde_protector_not_encrypted_with_cmk_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_tde_protector_not_encrypted_with_cmk_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "encrypt_tde_with_cmk"]

  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_servers_tde_protector_not_encrypted_with_cmk_key_id" {
  type        = string
  description = "The resource ID of Key Vault key ID to use for encryption."
  default     = "https://tets56.vault.azure.net/keys/azureuser/205729272cb34e108ceec99523031d89" // Add Key Vault key ID here

  tags = {
    folder = "Advanced/SQL"
  }
}

trigger "query" "detect_and_correct_sql_servers_tde_protector_not_encrypted_with_cmk" {
  title         = "Detect & correct SQL servers TDE protector not encrypted with CMK"
  description   = "Detect SQL servers TDE protector not encrypted with CMK."
  tags          = local.sql_common_tags

  enabled  = var.sql_servers_tde_protector_not_encrypted_with_cmk_trigger_enabled
  schedule = var.sql_servers_tde_protector_not_encrypted_with_cmk_trigger_schedule
  database = var.database
  sql      = local.sql_servers_tde_protector_not_encrypted_with_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_sql_servers_tde_protector_not_encrypted_with_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_servers_tde_protector_not_encrypted_with_cmk" {
  title         = "Detect & correct SQL servers TDE protector not encrypted with CMK"
  description   = "Detect SQL servers TDE protector not encrypted with CMK."
  tags          = local.sql_common_tags

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
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_default_action
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "key_id" {
    type        = string
    description = "The resource ID of Key Vault key ID to use for encryption."
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_key_id
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_servers_tde_protector_not_encrypted_with_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_servers_tde_protector_not_encrypted_with_cmk
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
      key_id                  = param.key_id
    }
  }
}

pipeline "correct_sql_servers_tde_protector_not_encrypted_with_cmk" {
  title         = "Correct SQL servers TDE protector not encrypted with CMK"
  description   = "Encrypt SQL servers TDE protector not encrypted with CMK for servers not encrypted with CMK."
  tags          = merge(local.sql_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      name            = string
      resource_group  = string
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
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_default_action
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "key_id" {
    type        = string
    description = "The resource ID of Key Vault key ID to use for encryption."
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_key_id
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} SQL server(s) TDE not encrypted with CMK."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_servers_tde_protector_not_encrypted_with_cmk
    args = {
      title                   = each.value.title
      name                    = each.value.name
      resource_group          = each.value.resource_group
      subscription_id         = each.value.subscription_id
      conn                    = connection.azure[each.value.conn]
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
      key_id                  = param.key_id
    }
  }
}

pipeline "correct_one_sql_servers_tde_protector_not_encrypted_with_cmk" {
  title         = "Correct SQL server TDE protector not encrypted with CMK"
  description   = "Encrypt SQL server TDE protector not encrypted with CMK for a server not encrypted with CMK."
  tags          = merge(local.sql_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the SQL server."
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
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_default_action
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions
    enum        = local.sql_servers_tde_protector_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "key_id" {
    type        = string
    description = "The resource ID of the Disk Encryption Set to use for encryption."
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL server ${param.title} TDE not encrypted with CMK."
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
            text     = "Skipped SQL server ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "encrypt_tde_with_cmk" = {
          label        = "Encrypt TDE with CMK"
          value        = "encrypt_tde_with_cmk"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_sql_server_tde_key
          pipeline_args = {
            server_name             = param.name
            resource_group          = param.resource_group
            subscription_id         = param.subscription_id
            conn                    = param.conn
            key_id                  = param.key_id
          }
          success_msg = "Enabled TDE with CMK for SQL server ${param.title}."
          error_msg   = "Error enabling TDE with CMK for SQL server ${param.title}."
        }
      }
    }
  }
}


