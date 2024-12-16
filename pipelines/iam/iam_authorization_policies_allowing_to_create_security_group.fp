locals {
  iam_authorization_policies_allowing_to_create_security_group_query = <<-EOQ
    with distinct_tenant as (
      select
        distinct tenant_id,
        subscription_id,
        _ctx
      from
        azure_tenant
    )
    select
      concat(a.id, ' [', t.tenant_id, ']') as title,
      t.tenant_id ,
      a._ctx ->> 'connection_name' as conn
    from
      distinct_tenant as t,
      azuread_authorization_policy as a
    where
      a.default_user_role_permissions ->> 'allowedToCreateSecurityGroups' = 'true';
  EOQ
}

variable "iam_authorization_policies_allowing_to_create_security_group_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_authorization_policies_allowing_to_create_security_group_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_authorization_policies_allowing_to_create_security_group" {
  title         = "Detect & correct Authorization policies allowing IAM users to create security group"
  description   = "Detect authorization policies allowing IAM users to create security group."
  tags          = local.iam_common_tags

  enabled  = var.iam_authorization_policies_allowing_to_create_security_group_trigger_enabled
  schedule = var.iam_authorization_policies_allowing_to_create_security_group_trigger_schedule
  database = var.database
  sql      = local.iam_authorization_policies_allowing_to_create_security_group_query

  capture "insert" {
    pipeline = pipeline.correct_iam_authorization_policies_allowing_to_create_security_group
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_authorization_policies_allowing_to_create_security_group" {
  title         = "Detect & correct authorization policies allowing IAM users to create security group"
  description   = "Detect authorization policies allowing IAM users to create security group."
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
    sql      = local.iam_authorization_policies_allowing_to_create_security_group_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_authorization_policies_allowing_to_create_security_group
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_iam_authorization_policies_allowing_to_create_security_group" {
  title         = "Correct Authorization policies allowing IAM users to create security group"
  description   = "Send notifications for authorization policies allowing IAM users to create security group."
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
    text     = "Detected ${length(param.items)} authorization policies allowing users to create security group."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected authorization policy ${each.value.title} allowing users to create security group."
  }
}
