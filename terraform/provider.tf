terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0" # Versão que introduziu o skip_provider_registration ou similar, mas vamos tentar a abordagem de skip
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}
