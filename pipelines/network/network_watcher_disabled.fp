locals {
  network_watcher_disabled_query = <<-EOQ
    select
      concat(loc.id, ' [', '/', loc.subscription_id, ']') as title,
      loc.id as id,
      loc.name as region,
			concat(loc.name, 'NetworkWatcherRG') as resource_group,
      loc.subscription_id,
      loc._ctx ->> 'connection_name' as cred
		from
			azure_location loc
			left join azure_network_watcher watcher on watcher.region = loc.name
			left join azure_subscription sub on sub.subscription_id = loc.subscription_id
		where
			watcher.id is null;
  EOQ
}

trigger "query" "detect_and_correct_network_watcher_disabled" {
  title         = "Detect & correct disabled Network Watchers"
  description   = "Detects disabled Network Watchers and runs your chosen action."
  tags          = merge(local.network_common_tags, { class = "security" })

  enabled  = var.network_watcher_disabled_trigger_enabled
  schedule = var.network_watcher_disabled_trigger_schedule
  database = var.database
  sql      = local.network_watcher_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_network_watcher_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_watcher_disabled" {
  title         = "Detect & correct disabled Network Watchers"
  description   = "Detects disabled Network Watchers and runs your chosen action."
  tags          = merge(local.network_common_tags, { class = "security", type = "featured" })

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
    default     = var.network_watcher_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_watcher_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_watcher_disabled
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

pipeline "correct_network_watcher_disabled" {
  title         = "Correct disabled Network Watchers"
  description   = "Runs corrective action on a collection of disabled Network Watchers."
  tags          = merge(local.network_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
			region          = string
      subscription_id = string
			resource_group  = string
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
    default     = var.network_watcher_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} disabled Network Watchers."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_watcher_disabled
    args = {
      title              = each.value.title
      region             = each.value.region
      subscription_id    = each.value.subscription_id
			resource_group     = each.value.resource_group
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_network_watcher_disabled" {
  title         = "Correct one disabled Network Watcher"
  description   = "Runs corrective action on a single disabled Network Watcher."
  tags          = merge(local.network_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "region" {
    type        = string
    description = "The name oth the region."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
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
    default     = var.network_watcher_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Network Watche disabled in region ${param.region}."
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
            text     = "Skipped Network Watcher disabled in region ${param.region}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_network_watcher" = {
          label        = "Enable Network Watcher"
          value        = "enable_network_watcher"
          style        = local.style_alert
          pipeline_ref = pipeline.enable_network_watcher
          pipeline_args = {
            subscription_id = param.subscription_id
            resource_group  = param.resource_group
						region          = param.region
            cred            = param.cred
          }
          success_msg = "Enabled Network Watcher in region ${param.region}."
          error_msg   = "Error enabling Network Watcher in region ${param.region}."
        }
      }
    }
  }
}

variable "network_watcher_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "network_watcher_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "network_watcher_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "network_watcher_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_network_watcher"]
}

pipeline "create_resource_group" {
  title = "Create Resource Group"
  description = "Create resource group."

  param "region" {
    type        = string
    description = "The name of the location."
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

 	param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  step "query" "get_resource_group" {
    database = var.database
    sql = <<-EOQ
      select
        name
      from
        azure_resource_group
      where
        name = '${param.resource_group}'
    EOQ
  }

  step "pipeline" "create_resource_group" {
    if       = length(step.query.get_resource_group.rows) == 0
    pipeline = azure.pipeline.create_resource_group
    args = {
      resource_group = param.resource_group
      region         = param.region
			subscription_id = param.subscription_id
			cred            = param.cred
    }
  }
}

pipeline "enable_network_watcher" {
  title       = "Enable Network Watcher"
  description = "Enable Network Watcher for a specified region."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "region" {
    type        = string
    description = "The region where the Network Watcher should be enabled."
  }

	step "pipeline" "create_resource_group" {
		pipeline = pipeline.create_resource_group
		args = {
			region          = param.region
			cred            = param.cred
			resource_group  = param.resource_group
			subscription_id = param.subscription_id
		}
	}

  step "container" "enable_network_watcher" {
		depends_on = [step.pipeline.create_resource_group]
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "network", "watcher", "configure",
      "--locations", param.region,
      "--resource-group", param.resource_group,
      "--enabled", "true",
      "--subscription", param.subscription_id
    ]

    env = credential.azure[param.cred].env
  }

  output "network_watcher" {
    description = "Details of the enabled Network Watcher."
    value       = jsondecode(step.container.enable_network_watcher.stdout)
  }
}
