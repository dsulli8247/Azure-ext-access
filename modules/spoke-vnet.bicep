// Standard Spoke VNet module

@description('Azure region for resources')
param location string

@description('Spoke VNet name')
param vnetName string

@description('Spoke VNet address prefix')
param vnetAddressPrefix string

@description('Workload subnet prefix')
param workloadSubnetPrefix string

@description('Hub firewall private IP for routing')
param hubFirewallPrivateIp string

// Route table for workload subnet to route through hub firewall
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
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

// Spoke VNet
resource spokeVNet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
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
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadSubnetPrefix
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

// Outputs
output vnetId string = spokeVNet.id
output vnetName string = spokeVNet.name
output workloadSubnetId string = '${spokeVNet.id}/subnets/snet-workload'
