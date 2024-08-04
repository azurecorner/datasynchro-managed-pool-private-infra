resource "azurerm_service_plan" "service_plan" {
  location            = var.resource_group_location
  name                = var.service_plan_name
  os_type             = var.os_type
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  depends_on          = [azurerm_resource_group.resource_group]
}
resource "azurerm_linux_function_app" "linux_function_app" {
  app_settings = {
    FUNCTION_APP_EDIT_MODE              = "readOnly"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    https_only                          = "true"
    APPINSIGHTS_INSTRUMENTATIONKEY      = azurerm_application_insights.application_insights.instrumentation_key
  }
  location                      = var.resource_group_location
  name                          = var.linux_function_app_name
  resource_group_name           = var.resource_group_name
  storage_account_name          = azurerm_storage_account.storage_account.name
  storage_account_access_key    = azurerm_storage_account.storage_account.primary_access_key
  service_plan_id               = azurerm_service_plan.service_plan.id
  virtual_network_subnet_id     = azurerm_subnet.outbound_subnet.id
  public_network_access_enabled = false
  identity {
    type = "SystemAssigned"
  }
  site_config {
    vnet_route_all_enabled = true
    use_32_bit_worker      = false
    always_on              = true
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }
  depends_on = [azurerm_service_plan.service_plan, azurerm_storage_account.storage_account, azurerm_application_insights.application_insights]
}

resource "azurerm_role_assignment" "function_app_storage_role_assignment" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.linux_function_app.identity[0].principal_id
  depends_on           = [azurerm_linux_function_app.linux_function_app, azurerm_storage_account.storage_account]
}

resource "azurerm_private_endpoint" "private_endpoint" {
  location            = var.resource_group_location
  name                = "pe-${var.linux_function_app_name}"
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.inbound_subnet.id
  private_service_connection {
    is_manual_connection           = false
    name                           = "pe-con-${var.linux_function_app_name}"
    private_connection_resource_id = azurerm_linux_function_app.linux_function_app.id
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.azurewebsites.id]
  }
  depends_on = [azurerm_private_dns_zone.azurewebsites, azurerm_linux_function_app.linux_function_app, azurerm_private_dns_zone_virtual_network_link.virtual_network_link_azurewebsites]
}
