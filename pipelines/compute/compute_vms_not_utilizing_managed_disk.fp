locals {
  compute_vms_not_utilizing_managed_disk_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      vm_id as id,
      subscription_id,
      _ctx ->> 'connection_name' as conn
		from
   		azure_compute_virtual_machine
		where
		  managed_disk_id is null;
  EOQ
}

variable "compute_vms_not_utilizing_managed_disk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_vms_not_utilizing_managed_disk_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_vms_not_utilizing_managed_disk" {
  title         = "Detect & correct Compute VMs not utilizing managed disk"
  description   = "Detects Compute VMs not utilizing managed disk."
  tags          = local.compute_common_tags

  enabled  = var.compute_vms_not_utilizing_managed_disk_trigger_enabled
  schedule = var.compute_vms_not_utilizing_managed_disk_trigger_schedule
  database = var.database
  sql      = local.compute_vms_not_utilizing_managed_disk_query

  capture "insert" {
    pipeline = pipeline.correct_compute_vms_not_utilizing_managed_disk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_vms_not_utilizing_managed_disk" {
  title         = "Detect & correct Compute VMs not utilizing managed disk"
  description   = "Detects Compute VMs not utilizing managed disk."
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
    sql      = local.compute_vms_not_utilizing_managed_disk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_vms_not_utilizing_managed_disk
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_compute_vms_not_utilizing_managed_disk" {
  title         = "Correct Compute VMs not utilizing managed diskk"
  description   = "Send notifications for Compute VMs not utilizing managed disk."
  tags         = merge(local.compute_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Compute VM(s) not utilizing managed disk."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Compute VM ${each.value.title} not utilizing managed disk."
  }
}
