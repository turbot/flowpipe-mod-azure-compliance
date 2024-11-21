locals {
  cosmosdb_accounts_with_virtual_network_filter_disabled_query = <<-EOQ
    select
      concat(a.id, ' [', a.subscription_id, '/', a.resource_group, ']') as title,
      a.id as id,
      subscription_id,
      _ctx ->> 'connection_name' as conn
		from
   		azure_cosmosdb_account as a
		where
		  public_network_access = 'Enabled' and is_virtual_network_filter_enabled = 'false';
  EOQ
}

variable "cosmosdb_accounts_with_virtual_network_filter_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/CosmosDB"
  }
}

variable "cosmosdb_accounts_with_virtual_network_filter_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/CosmosDB"
  }
}

trigger "query" "detect_and_correct_cosmosdb_accounts_with_virtual_network_filter_disabled" {
  title         = "Detect & correct Cosmos DB accounts with virtual network filter disabled"
  description   = "Detects Cosmos DB accounts with virtual network filter disabled."
  tags          = local.cosmosdb_common_tags

  enabled  = var.cosmosdb_accounts_with_virtual_network_filter_disabled_trigger_enabled
  schedule = var.cosmosdb_accounts_with_virtual_network_filter_disabled_trigger_schedule
  database = var.database
  sql      = local.cosmosdb_accounts_with_virtual_network_filter_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cosmosdb_accounts_with_virtual_network_filter_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cosmosdb_accounts_with_virtual_network_filter_disabled" {
  title         = "Detect & correct Cosmos DB accounts with virtual network filter disabled"
  description   = "Detects Cosmos DB accounts with virtual network filter disabled."
  tags          = local.cosmosdb_common_tags

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
    sql      = local.cosmosdb_accounts_with_virtual_network_filter_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cosmosdb_accounts_with_virtual_network_filter_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_cosmosdb_accounts_with_virtual_network_filter_disabled" {
  title         = "Correct Cosmos DB accounts with virtual network filter disabled"
  description   = "Send notifications for Cosmos DB accounts with virtual network filter disabled."
  tags         = merge(local.cosmosdb_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Cosmos DB account(s) with virtual network filter disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Cosmos DB account ${each.value.title} with virtual network filter disabled."
  }
}
