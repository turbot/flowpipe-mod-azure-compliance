locals {
  cosmosdb_accounts_not_using_private_link_query = <<-EOQ
    with cosmosdb_private_connection as (
      select
        distinct a.id
      from
        azure_cosmosdb_account as a,
        jsonb_array_elements(private_endpoint_connections) as connection
      where
        connection -> 'properties' -> 'privateLinkServiceConnectionState' ->> 'status' = 'Approved'
    )
    select
      concat(a.id, ' [', a.subscription_id, '/', a.resource_group, ']') as title,
      a.id as id,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_cosmosdb_account as a
      left join cosmosdb_private_connection as c on c.id = a.id
    where
      c.id is null;
  EOQ
}

variable "cosmosdb_accounts_not_using_private_link_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/CosmosDB"
  }
}

variable "cosmosdb_accounts_not_using_private_link_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/CosmosDB"
  }
}

trigger "query" "detect_and_correct_cosmosdb_accounts_not_using_private_link" {
  title         = "Detect & correct Cosmos DB accounts not using private link"
  description   = "Detects Cosmos DB accounts not using private link."
  tags          = local.cosmosdb_common_tags

  enabled  = var.cosmosdb_accounts_not_using_private_link_trigger_enabled
  schedule = var.cosmosdb_accounts_not_using_private_link_trigger_schedule
  database = var.database
  sql      = local.cosmosdb_accounts_not_using_private_link_query

  capture "insert" {
    pipeline = pipeline.correct_cosmosdb_accounts_not_using_private_link
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cosmosdb_accounts_not_using_private_link" {
  title         = "Detect & correct Cosmos DB accounts not using private link"
  description   = "Detects Cosmos DB accounts not using private link."
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
    sql      = local.cosmosdb_accounts_not_using_private_link_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cosmosdb_accounts_not_using_private_link
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_cosmosdb_accounts_not_using_private_link" {
  title         = "Correct Cosmos DB accounts not using private link"
  description   = "Send notifications for Cosmos DB accounts not using private link."
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
    text     = "Detected ${length(param.items)} Cosmos DB account(s) not using private link."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Cosmos DB account ${each.value.title} not using private link."
  }
}
