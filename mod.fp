mod "azure_compliance" {
  title         = "Azure Compliance"
  description   = "Run pipelines to detect and correct Azure resources that are non-compliant."
  color         = "#ea4335"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/azure-compliance.svg"
  categories    = ["azure", "cost", "compliance", "public cloud"]

  opengraph {
    title       = "Azure Compliance Mod for Flowpipe"
    description = "Run pipelines to detect and correct Azure resources that are non-compliant."
    image       = "/images/mods/turbot/azure-compliance-social-graphic.png"
  }

  require {
    mod "github.com/turbot/flowpipe-mod-azure" {
      version = "v1.0.1-rc.0"
    }
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "*"
    }
  }
}
