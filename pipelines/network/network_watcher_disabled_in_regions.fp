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

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} region(s) with network watcher disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected region ${each.value.title} with network watcher disabled.."
  }
}
