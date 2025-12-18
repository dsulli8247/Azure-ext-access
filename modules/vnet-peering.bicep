// VNet Peering module

@description('Local VNet name')
param localVNetName string

@description('Remote VNet name')
param remoteVNetName string

@description('Remote VNet resource ID')
param remoteVNetId string

@description('Allow forwarded traffic')
param allowForwardedTraffic bool = true

@description('Allow gateway transit')
param allowGatewayTransit bool = false

@description('Use remote gateways')
param useRemoteGateways bool = false

// Get reference to local VNet
resource localVNet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: localVNetName
}

// VNet Peering
resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: '${localVNetName}-to-${remoteVNetName}'
  parent: localVNet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVNetId
    }
  }
}

// Outputs
output peeringName string = vnetPeering.name
output peeringId string = vnetPeering.id
