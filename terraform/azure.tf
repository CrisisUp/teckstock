# # Grupo de Recursos
# resource "azurerm_resource_group" "main" {
#   name     = "rg-techstock-multicloud"
#   location = var.azure_location
# }
# 
# # Rede Virtual (VNet)
# resource "azurerm_virtual_network" "main" {
#   name                = "vnet-azure"
#   address_space       = [var.azure_vnet_cidr]
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
# 
#   tags = {
#     environment = "desafio-final"
#   }
# }
# 
# # Subrede para Monitoramento (Grafana + Prometheus)
# resource "azurerm_subnet" "monitoring" {
#   name                 = "subnet-monitoring"
#   resource_group_name  = azurerm_resource_group.main.name
#   virtual_network_name = azurerm_virtual_network.main.name
#   address_prefixes     = [var.azure_subnet_cidr]
# }
# 
# # Gateway Subnet (Necessária para a VPN futuramente)
# resource "azurerm_subnet" "gateway" {
#   name                 = "GatewaySubnet" # Nome obrigatorio para o VPN Gateway
#   resource_group_name  = azurerm_resource_group.main.name
#   virtual_network_name = azurerm_virtual_network.main.name
#   address_prefixes     = ["10.0.255.0/27"]
# }
