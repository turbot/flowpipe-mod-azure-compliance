locals {
  // cis_v210_7_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "7"
  // })

  cis_v210_7_control_mapping = {
    cis_v210_7_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.1 is a TODO control."}}
    cis_v210_7_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.2 is a TODO control."}}
    cis_v210_7_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.3 is a TODO control."}}
    cis_v210_7_4  =  {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.4 is a TODO control."}}
    cis_v210_7_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.5 is a manual control."}}
		cis_v210_7_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.6 is a manual control."}}
		cis_v210_7_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.7 is a manual control."}}
    cis_v210_7_8  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.8 is a TODO control."}}
		cis_v210_7_9  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 7.9 is a TODO control."}}
  }
}

variable "cis_v210_7_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 7 controls to enable"
  default     = [
    "cis_v210_7_1",
    "cis_v210_7_2",
    "cis_v210_7_3",
    "cis_v210_7_4",
    "cis_v210_7_5",
    "cis_v210_7_6",
    "cis_v210_7_7",
    "cis_v210_7_8",
		"cis_v210_7_9"
  ]
}


pipeline "cis_v210_7" {
  title         = "7 Virtual Machines"
  documentation = file("./cis_v210/docs/cis_v210_7.md")

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
    subject  = "Request to run CIS v2.1.0 Section 7: Virtual Machines?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 7: Virtual Machines?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_7" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 7: Virtual Machines"
  }

  step "pipeline" "cis_v210_7" {
    depends_on = [step.message.cis_v210_7]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_7_enabled_controls)-1)
    }

    pipeline = local.cis_v210_7_control_mapping[var.cis_v210_7_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_7_control_mapping[var.cis_v210_7_enabled_controls[loop.index]].additional_args)
  }
}
