locals {
  // cis_v210_9_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v210_9_control_mapping = {
    cis_v210_9_1  = {pipeline = pipeline.detect_and_correct_appservice_webapp_authentication_disabled, additional_args = {}}
    cis_v210_9_2  = {pipeline = pipeline.detect_and_correct_appservice_webapp_not_using_https, additional_args = {}}
    cis_v210_9_3  = {pipeline = pipeline.detect_and_correct_appservice_webapp_not_using_latest_tls_version, additional_args = {}}
    cis_v210_9_4  = {pipeline = pipeline.detect_and_correct_appservice_webapp_register_with_active_directory_disabled, additional_args = {}}
    cis_v210_9_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 9.5 is a manual control."}}
		cis_v210_9_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 9.6 is a manual control."}}
		cis_v210_9_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 9.7 is a manual control."}}
    cis_v210_9_8  = {pipeline = pipeline.detect_and_correct_appservice_webapp_not_using_latest_http_version, additional_args = {}}
    cis_v210_9_9  = {pipeline = pipeline.detect_and_correct_appservice_webapp_ftp_deployment_enabled, additional_args = {}}
		cis_v210_9_10  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 9.10 is a manual control."}}
  }
}

variable "cis_v210_9_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 9 controls to enable"
  default     = [
    "cis_v210_9_1_1",
    "cis_v210_9_1_2",
    "cis_v210_9_1_3",
    "cis_v210_9_1_4",
    "cis_v210_9_1_5",
    "cis_v210_9_1_6",
    "cis_v210_9_1_7",
    "cis_v210_9_1_8",
    "cis_v210_9_1_9",
    "cis_v210_9_1_10"
  ]
}


pipeline "cis_v210_9" {
  title         = "9 AppService"
  documentation = file("./cis_v210/docs/cis_v210_9.md")

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
    subject  = "Request to run CIS v2.1.0 Section 9: AppService?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 9: AppService?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_9" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 9: AppService"
  }

  step "pipeline" "cis_v210_9" {
    depends_on = [step.message.cis_v210_9]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_9_enabled_controls)-1)
    }

    pipeline = local.cis_v210_9_control_mapping[var.cis_v210_9_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_9_control_mapping[var.cis_v210_9_enabled_controls[loop.index]].additional_args)
  }
}
