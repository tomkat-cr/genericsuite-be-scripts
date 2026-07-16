provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      App       = var.app_name
      Stage     = var.stage
      ManagedBy = "opentofu"
      Ticket    = "GS-334"
    }
  }
}
