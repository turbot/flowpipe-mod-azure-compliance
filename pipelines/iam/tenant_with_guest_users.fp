locals {
  tenant_with_guest_users_query = <<-EOQ
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

  tenant_with_guest_users_enabled_actions_enum = ["skip", "disable_and_delete_guest_user"]
  tenant_with_guest_users_default_action_enum = ["notify", "skip", "disable_and_delete_guest_user"]
}

variable "tenant_with_guest_users_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "tenant_with_guest_users_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "tenant_with_guest_users_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "tenant_with_guest_users_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "disable_and_delete_guest_user"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_tenant_with_guest_users" {
  title         = "Detect & correct tenant with guest users"
  description   = "Detect tenant with guest users and then disable and delete guest user."
  tags          = local.iam_common_tags

  enabled  = var.tenant_with_guest_users_trigger_enabled
  schedule = var.tenant_with_guest_users_trigger_schedule
  database = var.database
  sql      = local.tenant_with_guest_users_query

  capture "insert" {
    pipeline = pipeline.correct_tenant_with_guest_users
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_tenant_with_guest_users" {
  title         = "Detect & correct tenant with guest users"
  description   = "Detect tenant with guest users and then disable and delete guest user."
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.tenant_with_guest_users_default_action
    enum        = local.tenant_with_guest_users_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.tenant_with_guest_users_enabled_actions
    enum        = local.tenant_with_guest_users_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.tenant_with_guest_users_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_tenant_with_guest_users
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

pipeline "correct_tenant_with_guest_users" {
  title         = "Correct tenant with guest users"
  description   = "Disable and delete guest users in tenant."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title               = string
      user_principal_name = string
      tenant_id           = string
      account_enabled     = bool
      conn                = string
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
    default     = var.tenant_with_guest_users_default_action
    enum        = local.tenant_with_guest_users_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.tenant_with_guest_users_enabled_actions
    enum        = local.tenant_with_guest_users_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} guest user(s) in tenant ${param.tenant_id}."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_tenant_with_one_guest_user
    args = {
      title               = each.value.title
      user_principal_name = each.value.user_principal_name
		  account_enabled     = each.value.account_enabled
      conn                = connection.azure[each.value.conn]
      notifier            = param.notifier
      notification_level  = param.notification_level
      approvers           = param.approvers
      default_action      = param.default_action
      enabled_actions     = param.enabled_actions
    }
  }
}

pipeline "correct_tenant_with_one_guest_user" {
  title         = "Correct tenant with guest user"
  description   = "Disable and delete guest user in tenant."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_principal_name" {
    type        = string
    description = "The user principal name of the guest user."
  }

  param "tenant_id" {
    type        = string
    description = "The Tenant ID of Azure."
  }

  param "account_enabled" {
    type        = bool
    description = "Specifies whether account is enabled or disabled."
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
    default     = var.tenant_with_guest_users_default_action
    enum        = local.tenant_with_guest_users_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.tenant_with_guest_users_enabled_actions
    enum        = local.tenant_with_guest_users_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected guest user ${param.title}."
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
            text     = "Skipped guest user ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "disable_and_delete_guest_user" = {
          label        = "Disable and delete guest user"
          value        = "disable_and_delete_guest_user"
          style        = local.style_alert
          pipeline_ref = pipeline.disable_and_delete_user
          pipeline_args = {
            user_principal_name = param.user_principal_name
            tenant_id           = param.tenant_id
            conn                = param.conn
          }
          success_msg = "Disabled and deleted the guest user ${param.title}."
          error_msg   = "Error deleting the guest user ${param.title}."
        }
      }
    }
  }
}

pipeline "disable_and_delete_user" {
  title       = "Disable and Delete Azure AD User"
  description = "Disable a user account in Azure AD and then delete the account."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "conn" {
    type        = connection.azure
    description = local.description_connection
    default     = connection.azure.default
  }

  param "user_principal_name" {
    type        = string
    description = "The User Principal Name of the user to be disabled and deleted."
  }

  step "container" "disable_user" {
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "ad", "user", "update",
      "--id", param.user_principal_name,
      "--account-enabled", "false"
    ]

    env = param.conn.env
  }

  step "container" "delete_user" {
		depends_on = [step.container.disable_user]
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "ad", "user", "delete",
      "--id", param.user_principal_name
    ]

    env = param.conn.env
  }

  output "user_status" {
    description = "The status of the user after the disable and delete operations."
    value       = "User ${param.user_principal_name} has been disabled and deleted."
  }
}
