locals {
  cis_v210_common_tags = merge(local.aws_compliance_common_tags, {
    cis         = "true"
    cis_version = "v2.1.0"
  })
  cis_v210_control_mapping = {
    cis_v210_1  = { pipeline = pipeline.cis_v210_1 }
    cis_v210_2  = { pipeline = pipeline.cis_v210_2 }
    cis_v210_3  = { pipeline = pipeline.cis_v210_3 }
    cis_v210_4  = { pipeline = pipeline.cis_v210_4 }
    cis_v210_5  = { pipeline = pipeline.cis_v210_5 }
    cis_v210_6  = { pipeline = pipeline.cis_v210_6 }
    cis_v210_7  = { pipeline = pipeline.cis_v210_7 }
    cis_v210_8  = { pipeline = pipeline.cis_v210_8 }
    cis_v210_9  = { pipeline = pipeline.cis_v210_9 }
    cis_v210_10 = { pipeline = pipeline.cis_v210_10 }
  }
}

variable "cis_v210_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 controls to enable"
  default     = ["cis_v210_1", "cis_v210_2", "cis_v210_3", "cis_v210_4", "cis_v210_5", "cis_v210_6", "cis_v210_7", "cis_v210_8", "cis_v210_9", "cis_v210_10",]
}

pipeline "cis_v210" {
  title         = "CIS v2.1.0"
  description   = "The CIS Amazon Web Services Foundations Benchmark provides prescriptive guidance for configuring security options for a subset of Amazon Web Services with an emphasis on foundational, testable, and architecture agnostic settings."
  documentation = file("./cis_v210/docs/cis_overview.md")

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

  step "pipeline" "cis_v210" {
  loop {
    until = loop.index >= (length(var.cis_v210_enabled_controls)-1)
  }

  pipeline = local.cis_v210_control_mapping[var.cis_v210_enabled_controls[loop.index]].pipeline
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

// TODO: Move this somewhere else
pipeline "manual_control" {
  title         = "Manual Control"
  description   = "This is a manual control that requires human intervention."
  documentation =  "" // TODO: Add documentation

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

  param "message" {
    type        = string
    description = "Message to display."
  }

  step "message" "manual_control" {
    notifier = notifier[param.notifier]
    text     = param.message
  }
}