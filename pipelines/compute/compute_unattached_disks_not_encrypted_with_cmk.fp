locals {
  compute_unattached_disks_not_encrypted_with_cmk_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
		  name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_compute_disk
    where
      disk_state != 'Attached'
      and encryption_type <> 'EncryptionAtRestWithCustomerKey';
  EOQ

  compute_unattached_disks_not_encrypted_with_cmk_enabled_actions_enum = ["skip", "enable_encryption"]
  compute_unattached_disks_not_encrypted_with_cmk_default_action_enum = ["notify", "skip", "enable_encryption"]
}

variable "compute_unattached_disks_not_encrypted_with_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_unattached_disks_not_encrypted_with_cmk_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_unattached_disks_not_encrypted_with_cmk_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_unattached_disks_not_encrypted_with_cmk_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_encryption"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_unattached_disks_not_encrypted_with_cmk_disk_encryption_set_id" {
  type        = string
  description = "The resource ID of the Disk Encryption Set to use for encryption."
  default     = "" // Add disk encryption set ID here

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_unattached_disks_not_encrypted_with_cmk" {
  title         = "Detect & correct unattached Compute disks not encrypted with CMK"
  description   = "Detect unattached Compute disks not encrypted with CMK then encrypt with CMK."
  tags          = local.compute_common_tags

  enabled  = var.compute_unattached_disks_not_encrypted_with_cmk_trigger_enabled
  schedule = var.compute_unattached_disks_not_encrypted_with_cmk_trigger_schedule
  database = var.database
  sql      = local.compute_unattached_disks_not_encrypted_with_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_compute_unattached_disks_not_encrypted_with_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_unattached_disks_not_encrypted_with_cmk" {
  title         = "Detect & correct unattached Compute disks not encrypted with CMK"
  description   = "Detect unattached Compute disks not encrypted with CMK then encrypt with CMK."
  tags          = local.compute_common_tags

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
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_default_action
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "disk_encryption_set_id" {
    type        = string
    description = "The resource ID of the Disk Encryption Set to use for encryption."
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_disk_encryption_set_id
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_unattached_disks_not_encrypted_with_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_unattached_disks_not_encrypted_with_cmk
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
      disk_encryption_set_id  = param.disk_encryption_set_id
    }
  }
}

pipeline "correct_compute_unattached_disks_not_encrypted_with_cmk" {
  title         = "Correct unattached Compute disks not encrypted with CMK"
  description   = "Encrypt unattached Compute disks with CMK for disks not encrypted with CMK."
  tags          = merge(local.compute_common_tags, { folder = "Internal" })

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
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_default_action
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "disk_encryption_set_id" {
    type        = string
    description = "The resource ID of the Disk Encryption Set to use for encryption."
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_disk_encryption_set_id
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disk(s) not encrypted with CMK."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_unattached_disk_not_encrypted_with_cmk
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
      disk_encryption_set_id  = param.disk_encryption_set_id
    }
  }
}

pipeline "correct_one_compute_unattached_disk_not_encrypted_with_cmk" {
  title         = "Correct unattached Compute disk not encrypted with CMK"
  description   = "Encrypt a unattached Compute disk with CMK for disk not encrypted with CMK."
  tags          = merge(local.compute_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Compute server."
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
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_default_action
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions
    enum        = local.compute_unattached_disks_not_encrypted_with_cmk_enabled_actions_enum
  }

  param "disk_encryption_set_id" {
    type        = string
    description = "The resource ID of the Disk Encryption Set to use for encryption."
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unattached Compute disk ${param.title} not encrypted with CMK."
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
            text     = "Skipped Compute disk ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_encryption" = {
          label        = "Enable encryption"
          value        = "enable_encryption"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_compute_disk_encryption_with_cmk
          pipeline_args = {
            disk_name               = param.name
            resource_group          = param.resource_group
            subscription_id         = param.subscription_id
            conn                    = param.conn
            disk_encryption_set_id  = param.disk_encryption_set_id
          }
          success_msg = "Enabled encryption with CMK for unattached Compute disk ${param.title}."
          error_msg   = "Error enabling encryption with CMK for unattached Compute disk ${param.title}."
        }
      }
    }
  }
}


