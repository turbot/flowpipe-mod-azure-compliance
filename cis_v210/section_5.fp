locals {
  // cis_v210_5_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "7"
  // })

  cis_v210_5_control_mapping = {
    cis_v210_5_1_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.1 is a manual control."}}
    cis_v210_5_1_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.2 is a TODO control."}}
    cis_v210_5_1_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.3 is a TODO control."}}
    cis_v210_5_1_4  =  {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.4 is a TODO control."}}
    cis_v210_5_1_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.5 is a manual control."}}
		cis_v210_5_1_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.1.6 is a manual control."}}
		cis_v210_5_2_1  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_create_policy_assignment, additional_args = {}}
		cis_v210_5_2_2  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_delete_policy_assignment, additional_args = {}}
		cis_v210_5_2_3  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_create_update_nsg, additional_args = {}}
		cis_v210_5_2_4  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_delete_nsg, additional_args = {}}
		cis_v210_5_2_5  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_create_update_security_solution, additional_args = {}}
		cis_v210_5_2_6  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_delete_security_solution, additional_args = {}}
		cis_v210_5_2_7  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_create_update_sql_servers_firewall_rule, additional_args = {}}
		cis_v210_5_2_8  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_delete_sql_servers_firewall_rule, additional_args = {}}
		cis_v210_5_2_9  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_update_public_ip_address, additional_args = {}}
		cis_v210_5_2_10  = {pipeline = pipeline.detect_and_correct_monitor_log_without_activity_log_alert_for_delete_public_ip_address, additional_args = {}}
		cis_v210_5_3_1  = = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.3.1 is a TODO control."}}
		cis_v210_5_4  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.4 is a manual control."}}
		cis_v210_5_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 5.5 is a manual control."}}

  }
}

variable "cis_v210_5_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 5 controls to enable"
  default     = [
    "cis_v210_5_1",
    "cis_v210_5_2",
    "cis_v210_5_3",
    "cis_v210_5_4",
    "cis_v210_5_5",
    "cis_v210_5_6",
    "cis_v210_5_7"
  ]
}


pipeline "cis_v210_5" {
  title         = "5 Logging and Monitoring"
  documentation = file("./cis_v210/docs/cis_v210_5.md")

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

  step "input" "should_run" {
    if       = (length(param.approvers) > 0)
    notifier = notifier[param.notifier]
    type     = "button"
    subject  = "Request to run CIS v2.1.0 Section 5: Logging and Monitoring?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 5: Logging and Monitoring?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_5" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 5: Logging and Monitoring"
  }

  step "pipeline" "cis_v210_5" {
    depends_on = [step.message.cis_v210_5]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_5_enabled_controls)-1)
    }

    pipeline = local.cis_v210_5_control_mapping[var.cis_v210_5_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_5_control_mapping[var.cis_v210_5_enabled_controls[loop.index]].additional_args)
  }
}
