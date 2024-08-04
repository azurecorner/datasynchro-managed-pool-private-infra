resource "azurerm_resource_group" "resource_group" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

resource "azurerm_virtual_network" "virtual_network" {
  address_space       = [var.virtual_network_address_space]
  location            = var.resource_group_location
  name                = var.virtual_network_name
  resource_group_name = var.resource_group_name
  depends_on = [
    azurerm_resource_group.resource_group,
  ]
}
resource "azurerm_subnet" "inbound_subnet" {
  address_prefixes     = [var.inbound_subnet_address_space]
  name                 = var.inbound_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  depends_on = [
    azurerm_virtual_network.virtual_network
  ]
}
resource "azurerm_subnet" "outbound_subnet" {
  address_prefixes     = [var.outbound_subnet_address_space]
  name                 = var.outbound_subnet_name
  resource_group_name  = var.resource_group_name
  service_endpoints    = ["Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  delegation {
    name = "delegation"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      name    = "Microsoft.Web/serverFarms"
    }
  }
  depends_on = [
    azurerm_virtual_network.virtual_network
  ]
}


resource "azurerm_private_dns_zone" "azurewebsites" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
  depends_on = [
    azurerm_resource_group.resource_group
  ]
}

resource "azurerm_private_dns_zone" "blob_core_windows" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name

  depends_on = [
    azurerm_resource_group.resource_group
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "virtual_network_link_azurewebsites" {
  name                  = "${var.virtual_network_name}-azurewebsites-link"
  private_dns_zone_name = azurerm_private_dns_zone.azurewebsites.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = azurerm_virtual_network.virtual_network.id
  depends_on = [
    azurerm_private_dns_zone.azurewebsites,
    azurerm_virtual_network.virtual_network
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "virtual_network_link_windows_web_core" {
  name                  = "${var.virtual_network_name}-windows_web_core-link"
  private_dns_zone_name = azurerm_private_dns_zone.blob_core_windows.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = azurerm_virtual_network.virtual_network.id
  depends_on = [
    azurerm_private_dns_zone.blob_core_windows,
    azurerm_virtual_network.virtual_network
  ]
}


resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = 30
  depends_on          = [azurerm_resource_group.resource_group]
}

resource "azurerm_application_insights" "application_insights" {
  name                = var.application_insights_name
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  workspace_id        = azurerm_log_analytics_workspace.log_analytics_workspace.id
  application_type    = "web"
  depends_on          = [azurerm_log_analytics_workspace.log_analytics_workspace]
}