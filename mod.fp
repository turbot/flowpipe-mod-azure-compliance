mod "azure_compliance" {
  title         = "Azure Compliance"
  description   = "Run pipelines to detect and correct Azure resources that are non-compliant."
  color         = "#0089D6"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/azure-compliance.svg"
  categories    = ["azure", "compliance", "public cloud", "standard"]

  opengraph {
    title       = "Azure Compliance Mod for Flowpipe"
    description = "Run pipelines to detect and correct Azure resources that are non-compliant."
    image       = "/images/mods/turbot/azure-compliance-social-graphic.png"
  }

  require {
    flowpipe {
      min_version = "1.0.0"
    }
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "^1"
    }
    mod "github.com/turbot/flowpipe-mod-azure" {
      version = "^1"
    }
  }
}
