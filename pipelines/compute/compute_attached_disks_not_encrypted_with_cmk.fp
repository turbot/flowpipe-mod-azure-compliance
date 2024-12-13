locals {
  compute_attached_disks_not_encrypted_with_cmk_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
		  name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_compute_disk
    where
      disk_state = 'Attached'
      and encryption_type <> 'EncryptionAtRestWithCustomerKey';
  EOQ
}

variable "compute_attached_disks_not_encrypted_with_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_attached_disks_not_encrypted_with_cmk_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_attached_disks_not_encrypted_with_cmk" {
  title         = "Detect & correct Compute disks not encrypted with CMK"
  description   = "Detect Compute disks not encrypted with CMK then encrypt with CMK."
  tags          = local.compute_common_tags

  enabled  = var.compute_attached_disks_not_encrypted_with_cmk_trigger_enabled
  schedule = var.compute_attached_disks_not_encrypted_with_cmk_trigger_schedule
  database = var.database
  sql      = local.compute_attached_disks_not_encrypted_with_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_compute_attached_disks_not_encrypted_with_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_attached_disks_not_encrypted_with_cmk" {
  title         = "Detect & correct Compute disks not encrypted with CMK"
  description   = "Detect Compute disks not encrypted with CMK then encrypt with CMK."
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

  step "query" "detect" {
    database = param.database
    sql      = local.compute_attached_disks_not_encrypted_with_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_attached_disks_not_encrypted_with_cmk
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
    }
  }
}

pipeline "correct_compute_attached_disks_not_encrypted_with_cmk" {
  title         = "Correct Compute disks not encrypted with CMK"
  description   = "Encrypt Compute disks with CMK for disks not encrypted with CMK."
  tags          = merge(local.compute_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Compute disk(s) not encrypted with CMK."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Compute disk ${each.value.title} not encrypted with CMK."
  }
}
