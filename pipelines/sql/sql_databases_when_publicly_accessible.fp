locals {
  sql_databases_when_publicly_accessible_query = <<-EOQ
		select
			distinct concat(s.id, ' [', s.subscription_id, '/', s.resource_group, '/firewallrule/', f ->> 'name',']') as title,
				s.id as id,
				s.name,
				f ->> 'name' as firewall_rule_name,
				s.resource_group,
				s.subscription_id,
				s._ctx ->> 'connection_name' as cred
		from
			azure_sql_server s,
			jsonb_array_elements(firewall_rules) as f,
			azure_subscription sub
		where
			sub.subscription_id = s.subscription_id
			and (
				(f -> 'properties' ->>  'endIpAddress' = '0.0.0.0' and f -> 'properties' ->>  'startIpAddress' = '0.0.0.0')
				or
				( f -> 'properties' ->>  'endIpAddress' = '255.255.255.255' and f -> 'properties' ->>  'startIpAddress' = '0.0.0.0')
		);
  EOQ
}

variable "sql_databases_when_publicly_accessible_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "sql_databases_when_publicly_accessible_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "sql_databases_when_publicly_accessible_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "sql_databases_when_publicly_accessible_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_firewall_rule"]
}

trigger "query" "detect_and_correct_sql_databases_when_publicly_accessible" {
  title         = "Detect & correct SQL Databases when publicly accessible"
  description   = "Detect SQL Databases firewall rules allowing public access and then delete the firewall rules."
  tags          = merge(local.sql_common_tags, { class = "security" })

  enabled  = var.sql_databases_when_publicly_accessible_trigger_enabled
  schedule = var.sql_databases_when_publicly_accessible_trigger_schedule
  database = var.database
  sql      = local.sql_databases_when_publicly_accessible_query

  capture "insert" {
    pipeline = pipeline.correct_sql_databases_when_publicly_accessible
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_databases_when_publicly_accessible" {
  title         = "Detect & correct SQL Databases when publicly accessible"
  description   = "Detect SQL Databases firewall rules allowing public access and then delete the firewall rules."
  tags          = merge(local.sql_common_tags, { class = "security", type = "featured" })

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
    default     = var.sql_databases_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_when_publicly_accessible_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_databases_when_publicly_accessible_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_databases_when_publicly_accessible
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

pipeline "correct_sql_databases_when_publicly_accessible" {
  title         = "Correct SQL Databases when publicly accessible"
  description   = "Delete firewall rule for SQL Databases allowing public access."
  tags          = merge(local.sql_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id                 = string
      title              = string
      name               = string
      resource_group     = string
			firewall_rule_name = string
      subscription_id    = string
      cred               = string
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
    default     = var.sql_databases_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_when_publicly_accessible_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} SQL Database(s) allowing public access."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_database_when_publicly_accessible
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
			firewall_rule_name = each.value.firewall_rule_name
      subscription_id    = each.value.subscription_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_sql_database_when_publicly_accessible" {
  title         = "Correct SQL Database when publicly accessible"
  description   = "Delete firewall rule fora  SQL Database allowing public access."
  tags          = merge(local.sql_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the SQL Database."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

 	param "firewall_rule_name" {
    type        = string
    description = "The firewall rule name."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
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
    default     = var.sql_databases_when_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_databases_when_publicly_accessible_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL Database ${param.title} allowing public access."
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
            text     = "Skipped SQL Database ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_firewall_rule" = {
          label        = "Delete Firewall Rule"
          value        = "delete_firewall_rule"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_sql_server_firewall_rule
          pipeline_args = {
            resource_group     = param.resource_group
            subscription_id    = param.subscription_id
            server_name        = param.name
            cred               = param.cred
            firewall_rule_name = param.firewall_rule_name
          }
          success_msg = "Deleted firewall rule allowing public access for SQL Database ${param.title}."
          error_msg   = "Error deleting firewall rule allowing public access for SQL Database ${param.title}."
        }
      }
    }
  }
}
