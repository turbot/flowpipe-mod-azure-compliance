locals {
  tenants_with_more_than_five_iam_global_administrator_query = <<-EOQ
    with distinct_tenant as (
      select
        distinct tenant_id
      from
        azure_tenant
    )
    select
      t.tenant_id as title,
      (jsonb_array_length(member_ids))::text as global_administrator_count,
      _ctx ->> 'connection_name' as conn
    from
      distinct_tenant as t,
      azuread_directory_role as p
    where
      display_name = 'Global Administrator'
      and jsonb_array_length(member_ids) > 5
  EOQ
}

variable "tenants_with_more_than_five_iam_global_administrator_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "tenants_with_more_than_five_iam_global_administrator_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_tenants_with_more_than_five_iam_global_administrator" {
  title         = "Detect & correct tenants with more than five IAM global administrator"
  description   = "Detect tenants with more than five IAM global administrator."
  tags          = local.iam_common_tags

  enabled  = var.tenants_with_more_than_five_iam_global_administrator_trigger_enabled
  schedule = var.tenants_with_more_than_five_iam_global_administrator_trigger_schedule
  database = var.database
  sql      = local.tenants_with_more_than_five_iam_global_administrator_query

  capture "insert" {
    pipeline = pipeline.correct_tenants_with_more_than_five_iam_global_administrator
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_tenants_with_more_than_five_iam_global_administrator" {
  title         = "Detect & correct tenants with more than five IAM global administrator"
  description   = "Detect tenants with more than five IAM global administrator."
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
    sql      = local.tenants_with_more_than_five_iam_global_administrator_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_tenants_with_more_than_five_iam_global_administrator
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_tenants_with_more_than_five_iam_global_administrator" {
  title         = "Correct tenants with more than five IAM global administrator"
  description   = "Send notifications for tenants with more than five IAM global administrator."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                        = string
      global_administrator_count   = string
      conn                         = string
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
    text     = "Detected ${length(param.items)} tenant(s) with more than five IAM global administrator."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected tenant ${each.value.title} with ${each.value.global_administrator_count} IAM global administrator."
  }
}
