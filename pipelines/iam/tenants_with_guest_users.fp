locals {
  tenants_with_guest_users_query = <<-EOQ
    with distinct_tenant as (
      select
        distinct tenant_id,
        subscription_id,
        _ctx
      from
        azure_tenant
    )
    select
      concat(display_name, ' [', u.tenant_id, ']') as title,
      u.tenant_id,
      u.user_principal_name as user_principal_name,
      account_enabled,
      extract(day from current_timestamp - u.created_date_time::timestamp),
      u._ctx ->> 'connection_name' as conn
    from
      azuread_user as u
      left join distinct_tenant as t on t.tenant_id = u.tenant_id
    where
      u.user_type = 'Guest';
  EOQ
}

variable "tenants_with_guest_users_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "tenants_with_guest_users_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_tenants_with_guest_users" {
  title         = "Detect & correct Tenants with guest users"
  description   = "Detect tenants with guest users."
  tags          = local.iam_common_tags

  enabled  = var.tenants_with_guest_users_trigger_enabled
  schedule = var.tenants_with_guest_users_trigger_schedule
  database = var.database
  sql      = local.tenants_with_guest_users_query

  capture "insert" {
    pipeline = pipeline.correct_tenants_with_guest_users
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_tenants_with_guest_users" {
  title         = "Detect & correct Tenants with guest users"
  description   = "Detect tenants with guest users."
  tags          = local.iam_common_tags

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
    sql      = local.tenants_with_guest_users_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_tenants_with_guest_users
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_tenants_with_guest_users" {
  title         = "Correct Tenants with guest users"
  description   = "Send notifications for tenants with guest users."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title   = string
      conn    = string
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
    text     = "Detected ${length(param.items)} guest user(s)."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected guest user ${each.value.title}."
  }
}
