locals {
  network_security_groups_allowing_rdp_access_query = <<-EOQ
    select
			concat(nsg.id, ' [', nsg.resource_group, '/', nsg.subscription_id, '/', sg ->> 'name', ']') as title,
			sg ->> 'name' as rule_name,
			nsg.name as sg_name,
			nsg.resource_group,
      nsg.subscription_id,
      nsg._ctx ->> 'connection_name' as cred
		from
			azure_network_security_group nsg,
			jsonb_array_elements(security_rules) sg,
			jsonb_array_elements_text(
				sg -> 'properties' -> 'destinationPortRanges' || (sg -> 'properties' -> 'destinationPortRange') :: jsonb
			) dport,
    jsonb_array_elements_text(
      sg -> 'properties' -> 'sourceAddressPrefixes' || (sg -> 'properties' -> 'sourceAddressPrefix') :: jsonb
    ) sip
	where
    sg -> 'properties' ->> 'access' = 'Allow'
    and sg -> 'properties' ->> 'direction' = 'Inbound'
    and (
      sg -> 'properties' ->> 'protocol' ilike 'TCP'
      or sg -> 'properties' ->> 'protocol' = '*'
    )
    and sip in (
      '*',
      '0.0.0.0',
      '0.0.0.0/0',
      'Internet',
      'any',
      '<nw>/0',
      '/0'
    )
    and (
      dport in ('3389', '*')
      or (
        dport like '%-%'
        and split_part(dport, '-', 1) :: integer <= 3389
        and split_part(dport, '-', 2) :: integer >= 3389
      )
    )
  EOQ
}

trigger "query" "detect_and_correct_network_security_groups_allowing_rdp_access" {
  title         = "Detect & correct NSGs allowing RDP access"
  description   = "Detects NSGs allowing RDP access and runs your chosen action."
  tags          = merge(local.network_common_tags, { class = "security" })

  enabled  = var.network_security_groups_allowing_rdp_access_trigger_enabled
  schedule = var.network_security_groups_allowing_rdp_access_trigger_schedule
  database = var.database
  sql      = local.network_security_groups_allowing_rdp_access_query

  capture "insert" {
    pipeline = pipeline.correct_network_security_groups_allowing_rdp_access
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_security_groups_allowing_rdp_access" {
  title         = "Detect & correct NSGs allowing RDP access"
  description   = "Detects NSGs allowing RDP access and runs your chosen action."
  tags          = merge(local.network_common_tags, { class = "security", type = "featured" })

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
    default     = var.network_security_groups_allowing_rdp_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_rdp_access_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_security_groups_allowing_rdp_access_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_security_groups_allowing_rdp_access
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

pipeline "correct_network_security_groups_allowing_rdp_access" {
  title         = "Correct NSGs allowing RDP access"
  description   = "Runs corrective action on a collection of NSGs allowing RDP access."
  tags          = merge(local.network_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      rule_name       = string
			sg_name         = string
      resource_group  = string
      subscription_id = string
      cred            = string
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
    default     = var.network_security_groups_allowing_rdp_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_rdp_access_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} NSGs allowing RDP access."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_security_groups_allowing_rdp_access
    args = {
      title              = each.value.title
      rule_name          = each.value.rule_name
			sg_name            = each.value.sg_name
      resource_group     = each.value.resource_group
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

pipeline "correct_one_network_security_groups_allowing_rdp_access" {
  title         = "Correct one NSG allowing RDP access"
  description   = "Runs corrective action on a single NSG allowing RDP access."
  tags          = merge(local.network_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

 	param "rule_name" {
    type        = string
    description = "The name of NSG rule."
  }

	param "sg_name" {
    type        = string
    description = "The name of NSG."
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
    default     = var.network_security_groups_allowing_rdp_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_rdp_access_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected NSG ${param.sg_name} allowing RDP access."
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
            text     = "Skipped NSG ${param.sg_name} allowing RDP access."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_rdp_nsg_rule" = {
          label        = "Delete RDP NSG Rule"
          value        = "delete_rdp_nsg_rule"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_network_nsg_rule
          pipeline_args = {
            resource_group     = param.resource_group
						nsg_name           = param.sg_name
						nsg_rule_name      = param.rule_name
            subscription_id    = param.subscription_id
            cred               = param.cred
          }
          success_msg = "Deleted RDP rule for NSG ${param.sg_name}."
          error_msg   = "Error deleting RDP rule for NSG ${param.sg_name}."
        }
      }
    }
  }
}

variable "network_security_groups_allowing_rdp_access_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "network_security_groups_allowing_rdp_access_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "network_security_groups_allowing_rdp_access_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "network_security_groups_allowing_rdp_access_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_rdp_nsg_rule"]
}
