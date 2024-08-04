locals {
  storage_subresources = ["blob", "file", "queue", "table"]
}

resource "azurerm_storage_account" "storage_account" {
  account_replication_type        = var.storage_account_replication_type
  account_tier                    = var.storage_account_tier
  location                        = var.resource_group_location
  name                            = var.storage_account_name
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  resource_group_name             = var.resource_group_name

  depends_on = [
    azurerm_resource_group.resource_group
  ]
}

resource "azurerm_storage_account_network_rules" "storage_account_network_rules" {
  storage_account_id = azurerm_storage_account.storage_account.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  virtual_network_subnet_ids = [azurerm_subnet.outbound_subnet.id]
  depends_on                 = [azurerm_storage_account.storage_account]
}


resource "azurerm_private_endpoint" "private_endpoint_storage" {
  for_each            = toset(local.storage_subresources)
  location            = var.resource_group_location
  name                = "pe-${var.storage_account_name}-${each.key}"
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.inbound_subnet.id
  private_service_connection {
    is_manual_connection           = false
    name                           = "pe-con-${var.storage_account_name}-${each.key}"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names              = [each.key]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_core_windows.id]
  }
  depends_on = [azurerm_private_dns_zone.blob_core_windows, azurerm_storage_account.storage_account, azurerm_private_dns_zone_virtual_network_link.virtual_network_link_azurewebsites]
}