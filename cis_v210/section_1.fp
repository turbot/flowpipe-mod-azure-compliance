locals {
  // cis_v210_1_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "1"
  // })
  cis_v210_1_control_mapping = {
    cis_v210_1_1_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.1.1 is a manual control."}}
    cis_v210_1_1_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.1.2 is a manual control."}}
    cis_v210_1_1_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.1.3 is a manual control."}}
    cis_v210_1_1_4  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.1.4 is a manual control."}}
    cis_v210_1_2_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.1 is a manual control."}}
    cis_v210_1_2_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.2 is a manual control."}}
    cis_v210_1_2_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.3 is a manual control."}}
    cis_v210_1_2_4  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.4 is a manual control."}}
    cis_v210_1_2_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.5 is a manual control."}}
    cis_v210_1_2_6 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.6 is a manual control."}}
    cis_v210_1_2_7 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.2.7 is a manual control."}}
    cis_v210_1_3 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.3 is a manual control."}}
    cis_v210_1_4 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.4 is a manual control."}}
    cis_v210_1_5 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.5 is a manual control."}}
    cis_v210_1_6 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.6 is a manual control."}}
    cis_v210_1_7 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.7 is a manual control."}}
    cis_v210_1_8 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.8 is a manual control."}}
    cis_v210_1_9 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.9 is a manual control."}}
    cis_v210_1_10 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.10 is a manual control."}}
    cis_v210_1_11 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.11 is a manual control."}}
    cis_v210_1_12 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.12 is a manual control."}}
    cis_v210_1_13 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.13 is a manual control."}}
    cis_v210_1_14 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.14 is a manual control."}}
    cis_v210_1_15 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.15 is a manual control."}}
    cis_v210_1_16 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.16 is a manual control."}}
    cis_v210_1_17 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.17 is a manual control."}}
    cis_v210_1_18 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.18 is a manual control."}}
    cis_v210_1_19 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.19 is a manual control."}}
    cis_v210_1_20 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.20 is a manual control."}}
    cis_v210_1_21 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.21 is a manual control."}}
    cis_v210_1_22 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.22 is a manual control."}}
    cis_v210_1_23 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.23 is a manual control."}}
    cis_v210_1_24 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.24 is a manual control."}}
    cis_v210_1_25 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 1.25 is a manual control."}}
  }
}

variable "cis_v210_1_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 1 controls to enable"
  default     = [
    "cis_v210_1_2",
    "cis_v210_1_4",
    "cis_v210_1_8",
    "cis_v210_1_9",
    "cis_v210_1_12",
    "cis_v210_1_13",
    "cis_v210_1_14",
    "cis_v210_1_15",
    "cis_v210_1_16",
    "cis_v210_1_20",
    "cis_v210_1_22"
  ]
}

pipeline "cis_v210_1" {
  title         = "1 Identity and Access Management"
  documentation = file("./cis_v210/docs/cis_v210_1.md")

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
    subject  = "Request to run CIS v2.1.0 Section 1: Identity and Access Management?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 1: Identity and Access Management?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_1" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 1: Identity and Access Management"
  }

  step "pipeline" "cis_v210_1" {
    depends_on = [step.message.cis_v210_1]
    if         = (step.transform.input_value.value == "yes")

    loop {
      until = (loop.index >= (length(var.cis_v210_1_enabled_controls)-1))
    }

    pipeline = local.cis_v210_1_control_mapping[var.cis_v210_1_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_1_control_mapping[var.cis_v210_1_enabled_controls[loop.index]].additional_args)
  }
}