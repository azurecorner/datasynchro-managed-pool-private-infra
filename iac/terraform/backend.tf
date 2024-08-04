terraform {
  backend "azurerm" {
    resource_group_name  = "RG_MANAGED_DEVOPS_POOL"
    storage_account_name = "tfbackendmdpmvp"
    container_name       = "backend-ado-tfstate"
    key                  = "terraform.tfstate"
  }
}

