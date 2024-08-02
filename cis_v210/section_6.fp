locals {
  // cis_v210_6_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "6"
  // })

  cis_v210_6_control_mapping = {
    cis_v210_6_1  = {pipeline = pipeline.detect_and_correct_network_security_group_allowing_rdp_access, additional_args = {}}
    cis_v210_6_2  = {pipeline = pipeline.detect_and_correct_network_security_group_allowing_ssh_access, additional_args = {}}
    cis_v210_6_3  = {pipeline = pipeline.detect_and_correct_network_security_group_allowing_udp_access, additional_args = {}}
    cis_v210_6_4  =  {pipeline = pipeline.detect_and_correct_network_security_group_allowing_https_access, additional_args = {}}
    cis_v210_6_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 6.5 is a TODO control."}}
		cis_v210_6_6  = {pipeline = pipeline.detect_and_correct_network_watcher_disabled, additional_args = {message = "CIS v2.1.0 6.6 is a manual control."}}
		cis_v210_6_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 6.7 is a manual control."}}
  }
}

variable "cis_v210_6_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 6 controls to enable"
  default     = [
    "cis_v210_6_1",
    "cis_v210_6_2",
    "cis_v210_6_3",
    "cis_v210_6_4",
    "cis_v210_6_5",
    "cis_v210_6_6",
    "cis_v210_6_7"
  ]
}


pipeline "cis_v210_6" {
  title         = "6 Networking"
  documentation = file("./cis_v210/docs/cis_v210_6.md")

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
    subject  = "Request to run CIS v2.1.0 Section 6: Networking?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 6: Networking?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_6" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 7: Networking"
  }

  step "pipeline" "cis_v210_6" {
    depends_on = [step.message.cis_v210_6]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_6_enabled_controls)-1)
    }

    pipeline = local.cis_v210_6_control_mapping[var.cis_v210_6_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_6_control_mapping[var.cis_v210_6_enabled_controls[loop.index]].additional_args)
  }
}
