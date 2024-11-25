locals {
  network_watcher_disabled_in_regions_query = <<-EOQ
    select
      concat(loc.name, ' [', loc.subscription_id, ']') as title,
      loc.id as id,
      loc.name as region,
      concat(loc.name, 'NetworkWatcherRG') as resource_group,
      loc.subscription_id,
      loc._ctx ->> 'connection_name' as conn
    from
      azure_location loc
      left join azure_network_watcher watcher on watcher.region = loc.name
      left join azure_subscription sub on sub.subscription_id = loc.subscription_id
    where
      watcher.id is null;
  EOQ

  network_watcher_disabled_in_regions_enabled_actions_enum = ["skip", "enable_network_watcher"]
  network_watcher_disabled_in_regions_default_action_enum = ["notify", "skip", "enable_network_watcher"]
}

variable "network_watcher_disabled_in_regions_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_watcher_disabled_in_regions_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_watcher_disabled_in_regions_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_watcher_disabled_in_regions_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_network_watcher"]

  tags = {
    folder = "Advanced/Network"
  }
}

trigger "query" "detect_and_correct_network_watcher_disabled_in_regions" {
  title         = "Detect & correct regions with network watcher disabled"
  description   = "Detects regions with network watcher disabled and then enable them."
  tags          = local.network_common_tags

  enabled  = var.network_watcher_disabled_in_regions_trigger_enabled
  schedule = var.network_watcher_disabled_in_regions_trigger_schedule
  database = var.database
  sql      = local.network_watcher_disabled_in_regions_query

  capture "insert" {
    pipeline = pipeline.correct_network_watcher_disabled_in_regions
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_watcher_disabled_in_regions" {
  title         = "Detect & correct regions with network watcher disabled"
  description   = "Detects regions with network watcher disabled and then enable them."
  tags          = local.network_common_tags

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
    default     = var.network_watcher_disabled_in_regions_default_action
    enum        = local.network_watcher_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_in_regions_enabled_actions
    enum        = local.network_watcher_disabled_in_regions_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_watcher_disabled_in_regions_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_watcher_disabled_in_regions
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

pipeline "correct_network_watcher_disabled_in_regions" {
  title         = "Correct regions with network watcher disabled"
  description   = "Enable network watcher in regions with network watcher disabled."
  tags          = merge(local.network_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
			region          = string
      subscription_id = string
			resource_group  = string
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
    default     = var.network_watcher_disabled_in_regions_default_action
    enum        = local.network_watcher_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_in_regions_enabled_actions
    enum        = local.network_watcher_disabled_in_regions_enabled_actions_enum
  }


  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} region(s) with network watcher disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_watcher_disabled_in_region
    args = {
      title              = each.value.title
      region             = each.value.region
      subscription_id    = each.value.subscription_id
			resource_group     = each.value.resource_group
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_network_watcher_disabled_in_region" {
  title         = "Correct one region with network watcher disabled"
  description   = "Enable network watcher in a region with network watcher disabled."
  tags          = merge(local.network_common_tags, { folder = "Internal" })

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
    default     = var.network_watcher_disabled_in_regions_default_action
    enum        = local.network_watcher_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_watcher_disabled_in_regions_enabled_actions
    enum        = local.network_watcher_disabled_in_regions_enabled_actions_enum
  }


  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected region ${param.title} with network watcher disabled."
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
            text     = "Skipped region ${param.region}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_network_watcher" = {
          label        = "Enable network watcher"
          value        = "enable_network_watcher"
          style        = local.style_alert
          pipeline_ref = pipeline.enable_network_watcher
          pipeline_args = {
            subscription_id = param.subscription_id
            resource_group  = param.resource_group
            region          = param.region
            conn            = param.conn
          }
          success_msg = "Enabled network watcher in region ${param.title}."
          error_msg   = "Error enabling network watcher in region ${param.title}."
        }
      }
    }
  }
}

pipeline "create_resource_group_for_network_watcher" {
  title        = "Create Resource Group"
  description  = "Create resource group."
  tags         = merge(local.network_common_tags, { folder = "Internal" })

  param "region" {
    type        = string
    description = "The name of the location."
    default   = "australiaeast"
  }

  param "conn" {
    type        = connection.azure
    description = local.description_connection
    default     = connection.azure.default
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
    default     = "australiaeastNetworkWatcherRG"
  }

 	param "subscription_id" {
    type        = string
    description = local.description_subscription_id
     default     = "d46d7416-f95f-4771-bbb5-529d4c76659c"
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
        and sp_connection_name = '${param.conn.short_name}';
    EOQ
  }

  step "pipeline" "create_resource_group_for_network_watcher" {
    depends_on = [step.query.get_resource_group]
    if       = length(step.query.get_resource_group.rows) == 0
    pipeline = azure.pipeline.create_resource_group
    args = {
      resource_group  = param.resource_group
      region          = param.region
			subscription_id = param.subscription_id
			conn            = param.conn
    }
  }
}

pipeline "enable_network_watcher" {
  title        = "Enable Network Watcher"
  description  = "Enable Network Watcher for a specified region."
  tags         = merge(local.network_common_tags, { folder = "Internal" })

  param "conn" {
    type        = connection.azure
    description = local.description_connection
    default     = connection.azure.default
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

	step "pipeline" "create_resource_group_for_network_watcher" {
		pipeline = pipeline.create_resource_group_for_network_watcher
		args = {
			region          = param.region
			conn            = param.conn
			resource_group  = param.resource_group
			subscription_id = param.subscription_id
		}
	}

  step "container" "enable_network_watcher" {
		depends_on = [step.pipeline.create_resource_group_for_network_watcher]
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "network", "watcher", "configure",
      "--locations", param.region,
      "--resource-group", param.resource_group,
      "--enabled", "true",
      "--subscription", param.subscription_id
    ]

    env = connection.azure[param.conn].env
  }

  output "network_watcher" {
    description = "Details of the enabled Network Watcher."
    value       = jsondecode(step.container.enable_network_watcher.stdout)
  }
}
