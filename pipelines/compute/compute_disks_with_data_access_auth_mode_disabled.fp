locals {
  compute_disks_with_data_access_auth_mode_disabled_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
		  name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_compute_disk
    where
      data_access_auth_mode <> 'AzureActiveDirectory';
  EOQ

  compute_disks_with_data_access_auth_mode_disabled_enabled_actions_enum = ["skip", "enable_data_access_auth_mode"]
  compute_disks_with_data_access_auth_mode_disabled_default_action_enum = ["notify", "skip", "enable_data_access_auth_mode"]
}

variable "compute_disks_with_data_access_auth_mode_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_data_access_auth_mode_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_data_access_auth_mode_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_with_data_access_auth_mode_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_data_access_auth_mode"]

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_disks_with_data_access_auth_mode_disabled" {
  title         = "Detect & correct Compute disks with data access auth mode disabled"
  description   = "Detect Compute disks with data access auth mode disabled and then enable data access auth mode."
  tags          = local.compute_common_tags

  enabled  = var.compute_disks_with_data_access_auth_mode_disabled_trigger_enabled
  schedule = var.compute_disks_with_data_access_auth_mode_disabled_trigger_schedule
  database = var.database
  sql      = local.compute_disks_with_data_access_auth_mode_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_with_data_access_auth_mode_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_with_data_access_auth_mode_disabled" {
  title         = "Detect & correct Compute disks with data access auth mode disabled"
  description   = "Detect Compute disks with data access auth mode disabled and then enable data access auth mode."
  tags          = merge(local.compute_common_tags, { recommended = "true" })

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
    default     = var.compute_disks_with_data_access_auth_mode_disabled_default_action
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_data_access_auth_mode_disabled_enabled_actions
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_with_data_access_auth_mode_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_with_data_access_auth_mode_disabled
    args = {
      items                   = step.query.detect.rows
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
    }
  }
}

pipeline "correct_compute_disks_with_data_access_auth_mode_disabled" {
  title         = "Correct Compute disks with data access auth mode disabled"
  description   = "Enable data access auth mode for Compute disks with data access auth mode disabled."
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
    default     = var.compute_disks_with_data_access_auth_mode_disabled_default_action
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_data_access_auth_mode_disabled_enabled_actions
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disk(s) with data access auth mode disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_with_data_access_auth_mode_disabled
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
    }
  }
}

pipeline "correct_one_compute_disk_with_data_access_auth_mode_disabled" {
  title         = "Correct Compute disk with data access auth mode disabled"
  description   = "Enable data access auth mode for Compute disk with data access auth mode disabled."
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
    default     = var.compute_disks_with_data_access_auth_mode_disabled_default_action
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_data_access_auth_mode_disabled_enabled_actions
    enum        = local.compute_disks_with_data_access_auth_mode_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.title} with data access auth mode disabled."
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
        "enable_data_access_auth_mode" = {
          label        = "Enable data access auth mode"
          value        = "enable_data_access_auth_mode"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.update_compute_disk
          pipeline_args = {
            disk_name               = param.name
            resource_group          = param.resource_group
            subscription_id         = param.subscription_id
            conn                    = param.conn
            data_access_auth_mode   = true
          }
          success_msg = "Enabled data access auth mode for Compute disk ${param.title}."
          error_msg   = "Error enabling data access auth mode for Compute disk ${param.title}."
        }
      }
    }
  }
}


