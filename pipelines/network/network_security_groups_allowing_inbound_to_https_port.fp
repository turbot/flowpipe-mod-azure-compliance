locals {
  network_security_groups_allowing_inbound_to_https_port_query = <<-EOQ
    select
      concat(nsg.id, ' [', nsg.subscription_id, '/', nsg.resource_group, '/', sg ->> 'name', ']') as title,
      sg ->> 'name' as rule_name,
      nsg.name as sg_name,
      sip as source_address,
      dport as destination_port,
      nsg.resource_group,
      nsg.subscription_id,
      nsg._ctx ->> 'connection_name' as conn
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
      and sg -> 'properties' ->> 'protocol' ilike 'TCP'
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
        dport in ('80', '443', '*')
      or (
        dport like '%-%'
        and split_part(dport, '-', 1) :: integer <= 80
        and split_part(dport, '-', 2) :: integer >= 80
      )
      or (
        dport like '%-%'
        and split_part(dport, '-', 1) :: integer <= 443
        and split_part(dport, '-', 2) :: integer >= 443
      )
    )
  EOQ

  network_security_groups_allowing_inbound_to_https_port_enabled_actions_enum = ["skip", "revoke_nsg_rule"]
  network_security_groups_allowing_inbound_to_https_port_default_action_enum = ["notify", "skip", "revoke_nsg_rule"]
}

variable "network_security_groups_allowing_inbound_to_https_port_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_security_groups_allowing_inbound_to_https_port_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_security_groups_allowing_inbound_to_https_port_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Network"
  }
}

variable "network_security_groups_allowing_inbound_to_https_port_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "revoke_nsg_rule"]

  tags = {
    folder = "Advanced/Network"
  }
}

trigger "query" "detect_and_correct_network_security_groups_allowing_inbound_to_https_port" {
  title         = "Detect & correct NSGs allowing inbound to HTTPS port"
  description   = "Detect NSGs that allow inbound from 0.0.0.0/0 to HTTPS port and then revoke NSG rule."
  tags          = local.network_common_tags

  enabled  = var.network_security_groups_allowing_inbound_to_https_port_trigger_enabled
  schedule = var.network_security_groups_allowing_inbound_to_https_port_trigger_schedule
  database = var.database
  sql      = local.network_security_groups_allowing_inbound_to_https_port_query

  capture "insert" {
    pipeline = pipeline.correct_network_security_groups_allowing_inbound_to_https_port
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_network_security_groups_allowing_inbound_to_https_port" {
  title         = "Detect & correct NSGs allowing inbound to HTTPS port"
  description   = "Detect NSGs that allow inbound from 0.0.0.0/0 to HTTPS port and then revoke NSG rule."
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.network_security_groups_allowing_inbound_to_https_port_default_action
    enum        = local.network_security_groups_allowing_inbound_to_https_port_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_inbound_to_https_port_enabled_actions
    enum        = local.network_security_groups_allowing_inbound_to_https_port_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.network_security_groups_allowing_inbound_to_https_port_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_network_security_groups_allowing_inbound_to_https_port
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

pipeline "correct_network_security_groups_allowing_inbound_to_https_port" {
  title         = "Correct NSGs allowing inbound to HTTPS port"
  description   = "Revoke NSG rule entries to restrict access to HTTPS port from 0.0.0.0/0."
  tags          = merge(local.network_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title            = string
      rule_name        = string
      sg_name          = string
      destination_port = string
      source_address   = string
      resource_group   = string
      subscription_id  = string
      conn             = string
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
    default     = var.network_security_groups_allowing_inbound_to_https_port_default_action
    enum        = local.network_security_groups_allowing_inbound_to_https_port_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_inbound_to_https_port_enabled_actions
    enum        = local.network_security_groups_allowing_inbound_to_https_port_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} NSG rule(s) allowing inbound to HTTPS port from 0.0.0.0/0."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_network_security_group_allowing_inbound_to_https_port
    args = {
      title              = each.value.title
      rule_name          = each.value.rule_name
      sg_name            = each.value.sg_name
      destination_port   = each.value.destination_port
      source_address     = each.value.source_address
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_network_security_group_allowing_inbound_to_https_port" {
  title         = "Correct one NSG allowing inbound to HTTPS port"
  description   = "Revoke a NSG rule allowing ingress to HTTPS port from 0.0.0.0/0."
  tags          = merge(local.network_common_tags, { folder = "Internal" })

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

  param "destination_port" {
    type        = string
    description = "The destination port."
  }

  param "source_address" {
    type        = string
    description = "The source address."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
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
    default     = var.network_security_groups_allowing_inbound_to_https_port_default_action
    enum        = local.network_security_groups_allowing_inbound_to_https_port_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.network_security_groups_allowing_inbound_to_https_port_enabled_actions
    enum        = local.network_security_groups_allowing_inbound_to_https_port_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected NSG rule ${param.rule_name} in ${param.sg_name}/${param.subscription_id} allowing inbound on HTTPS and port(s) ${param.destination_port} from ${param.source_address}."
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
            text     = "Skipped NSG rule ${param.rule_name} in ${param.sg_name}/${param.subscription_id}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "revoke_nsg_rule" = {
          label        = "Delete HTTPS NSG Rule"
          value        = "revoke_nsg_rule"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_network_nsg_rule
          pipeline_args = {
            resource_group     = param.resource_group
            nsg_name           = param.sg_name
            nsg_rule_name      = param.rule_name
            subscription_id    = param.subscription_id
            conn               = param.conn
          }
          success_msg = "Revoked NSG rule ${param.rule_name} from ${param.sg_name}/${param.subscription_id}."
          error_msg   = "Error revoking NSG inbound rule ${param.rule_name} from security group ${param.sg_name}/${param.subscription_id}."
        }
      }
    }
  }
}
