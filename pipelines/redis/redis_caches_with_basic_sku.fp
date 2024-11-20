locals {
  redis_caches_with_basic_sku_query = <<-EOQ
   	select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_redis_cache
    where
			sku_name = 'Basic';
  EOQ
}

variable "redis_caches_with_basic_sku_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Redis"
  }
}

variable "redis_caches_with_basic_sku_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Redis"
  }
}

trigger "query" "detect_and_correct_redis_caches_with_basic_sku" {
  title         = "Detect & correct Redis Caches with basic SKU"
  description   = "Detects Redis Caches with basic SKU."
  tags          = local.redis_common_tags

  enabled  = var.redis_caches_with_basic_sku_trigger_enabled
  schedule = var.redis_caches_with_basic_sku_trigger_schedule
  database = var.database
  sql      = local.redis_caches_with_basic_sku_query

  capture "insert" {
    pipeline = pipeline.correct_redis_caches_with_basic_sku
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_redis_caches_with_basic_sku" {
  title         = "Detect & correct Redis Caches with basic SKU"
  description   = "Detects Redis Caches with basic SKU."
  tags          = local.redis_common_tags

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
    sql      = local.redis_caches_with_basic_sku_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_redis_caches_with_basic_sku
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_redis_caches_with_basic_sku" {
  title         = "Correct Redis Cache using basic SKU"
  description   = "Send notifications for a Redis Cache using basic SKU."
  tags         = merge(local.redis_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Redis Cache(s) using basic SKU."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Redis Cache ${each.value.title} using basic SKU."
  }
}
