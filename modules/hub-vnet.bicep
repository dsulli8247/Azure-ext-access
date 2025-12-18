// Hub VNet with Azure Firewall module

@description('Azure region for resources')
param location string

@description('Hub VNet name')
param vnetName string

@description('Hub VNet address prefix')
param vnetAddressPrefix string

@description('Azure Firewall subnet prefix')
param azureFirewallSubnetPrefix string

@description('Gateway subnet prefix')
param gatewaySubnetPrefix string

@description('Bastion subnet prefix')
param bastionSubnetPrefix string

// Hub VNet
resource hubVNet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// Public IP for Azure Firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${vnetName}-firewall'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: 'afwp-${vnetName}'
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: 'afw-${vnetName}'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: firewallPublicIp.id
          }
          subnet: {
            id: '${hubVNet.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// Outputs
output vnetId string = hubVNet.id
output vnetName string = hubVNet.name
output firewallId string = firewall.id
output firewallName string = firewall.name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = firewallPublicIp.properties.ipAddress
