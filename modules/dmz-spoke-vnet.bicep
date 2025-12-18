// DMZ Spoke VNet with Azure Firewall and WAF module

@description('Azure region for resources')
param location string

@description('DMZ Spoke VNet name')
param vnetName string

@description('DMZ Spoke VNet address prefix')
param vnetAddressPrefix string

@description('Azure Firewall subnet prefix')
param azureFirewallSubnetPrefix string

@description('Application Gateway (WAF) subnet prefix')
param appGatewaySubnetPrefix string

@description('Workload subnet prefix')
param workloadSubnetPrefix string

@description('Hub firewall private IP for routing')
param hubFirewallPrivateIp string

// Route table for workload subnet to route through hub firewall
resource workloadRouteTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-${vnetName}-workload'
  location: location
  properties: {
    routes: [
      {
        name: 'route-to-hub-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewallPrivateIp
        }
      }
    ]
    disableBgpRoutePropagation: false
  }
}

// DMZ Spoke VNet
resource dmzSpokeVNet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
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
        name: 'snet-appgateway'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
        }
      }
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadSubnetPrefix
          routeTable: {
            id: workloadRouteTable.id
          }
        }
      }
    ]
  }
}

// Public IP for DMZ Azure Firewall
resource dmzFirewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
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

// DMZ Azure Firewall Policy
resource dmzFirewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: 'afwp-${vnetName}'
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

// DMZ Azure Firewall
resource dmzFirewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
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
            id: dmzFirewallPublicIp.id
          }
          subnet: {
            id: '${dmzSpokeVNet.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    firewallPolicy: {
      id: dmzFirewallPolicy.id
    }
  }
}

// Public IP for Application Gateway (WAF)
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${vnetName}-appgateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Application Gateway (WAF)
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: 'agw-${vnetName}'
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${dmzSpokeVNet.id}/subnets/snet-appgateway'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultBackendPool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'defaultHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-${vnetName}', 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-${vnetName}', 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-${vnetName}', 'defaultHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-${vnetName}', 'defaultBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-${vnetName}', 'defaultHttpSettings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
  }
}

// Outputs
output vnetId string = dmzSpokeVNet.id
output vnetName string = dmzSpokeVNet.name
output firewallId string = dmzFirewall.id
output firewallName string = dmzFirewall.name
output firewallPrivateIp string = dmzFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output appGatewayId string = appGateway.id
output appGatewayName string = appGateway.name
output appGatewayPublicIp string = appGatewayPublicIp.properties.ipAddress
output workloadSubnetId string = '${dmzSpokeVNet.id}/subnets/snet-workload'
