// Main Bicep file for Azure Hub-Spoke Architecture
// This deploys a hub VNet with Azure Firewall and 3 spoke VNets
// DMZ spoke includes Azure Firewall and WAF

targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'eastus'

@description('Resource group name')
param resourceGroupName string = 'rg-hub-spoke-network'

@description('Hub VNet configuration')
param hubVNetConfig object = {
  name: 'vnet-hub'
  addressPrefix: '10.0.0.0/16'
  azureFirewallSubnetPrefix: '10.0.1.0/24'
  gatewaySubnetPrefix: '10.0.2.0/24'
  bastionSubnetPrefix: '10.0.3.0/24'
}

@description('Spoke VNet configurations')
param spokeVNetConfigs array = [
  {
    name: 'vnet-spoke1'
    addressPrefix: '10.1.0.0/16'
    workloadSubnetPrefix: '10.1.1.0/24'
  }
  {
    name: 'vnet-spoke2'
    addressPrefix: '10.2.0.0/16'
    workloadSubnetPrefix: '10.2.1.0/24'
  }
]

@description('DMZ Spoke VNet configuration')
param dmzSpokeVNetConfig object = {
  name: 'vnet-dmz-spoke'
  addressPrefix: '10.3.0.0/16'
  azureFirewallSubnetPrefix: '10.3.1.0/24'
  appGatewaySubnetPrefix: '10.3.2.0/24'
  workloadSubnetPrefix: '10.3.3.0/24'
  aksSubnetPrefix: '10.3.4.0/24'
}

@description('AKS cluster configuration')
param aksConfig object = {
  enabled: true
  clusterName: 'aks-dmz-cluster'
  dnsPrefix: 'aks-dmz'
  kubernetesVersion: '1.32.0'
  nodePoolVmSize: 'Standard_DS2_v2'
  nodeCount: 2
  minNodeCount: 1
  maxNodeCount: 3
}

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// Deploy Hub VNet with Azure Firewall
module hubVNet 'modules/hub-vnet.bicep' = {
  name: 'deploy-hub-vnet'
  scope: rg
  params: {
    location: location
    vnetName: hubVNetConfig.name
    vnetAddressPrefix: hubVNetConfig.addressPrefix
    azureFirewallSubnetPrefix: hubVNetConfig.azureFirewallSubnetPrefix
    gatewaySubnetPrefix: hubVNetConfig.gatewaySubnetPrefix
    bastionSubnetPrefix: hubVNetConfig.bastionSubnetPrefix
  }
}

// Deploy Standard Spoke VNets
module spokeVNets 'modules/spoke-vnet.bicep' = [for (spoke, i) in spokeVNetConfigs: {
  name: 'deploy-${spoke.name}'
  scope: rg
  params: {
    location: location
    vnetName: spoke.name
    vnetAddressPrefix: spoke.addressPrefix
    workloadSubnetPrefix: spoke.workloadSubnetPrefix
    hubFirewallPrivateIp: hubVNet.outputs.firewallPrivateIp
  }
}]

// Deploy DMZ Spoke VNet with Firewall and WAF
module dmzSpokeVNet 'modules/dmz-spoke-vnet.bicep' = {
  name: 'deploy-dmz-spoke-vnet'
  scope: rg
  params: {
    location: location
    vnetName: dmzSpokeVNetConfig.name
    vnetAddressPrefix: dmzSpokeVNetConfig.addressPrefix
    azureFirewallSubnetPrefix: dmzSpokeVNetConfig.azureFirewallSubnetPrefix
    appGatewaySubnetPrefix: dmzSpokeVNetConfig.appGatewaySubnetPrefix
    workloadSubnetPrefix: dmzSpokeVNetConfig.workloadSubnetPrefix
    aksSubnetPrefix: dmzSpokeVNetConfig.aksSubnetPrefix
    hubFirewallPrivateIp: hubVNet.outputs.firewallPrivateIp
  }
}

// Create VNet Peerings - Hub to Spokes
module hubToSpokePeerings 'modules/vnet-peering.bicep' = [for (spoke, i) in spokeVNetConfigs: {
  name: 'peering-hub-to-${spoke.name}'
  scope: rg
  params: {
    localVNetName: hubVNetConfig.name
    remoteVNetName: spoke.name
    remoteVNetId: spokeVNets[i].outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
  dependsOn: [
    hubVNet
    spokeVNets
  ]
}]

// Create VNet Peerings - Spokes to Hub
module spokeToHubPeerings 'modules/vnet-peering.bicep' = [for (spoke, i) in spokeVNetConfigs: {
  name: 'peering-${spoke.name}-to-hub'
  scope: rg
  params: {
    localVNetName: spoke.name
    remoteVNetName: hubVNetConfig.name
    remoteVNetId: hubVNet.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubVNet
    spokeVNets
  ]
}]

// Create VNet Peering - Hub to DMZ Spoke
module hubToDmzPeering 'modules/vnet-peering.bicep' = {
  name: 'peering-hub-to-dmz'
  scope: rg
  params: {
    localVNetName: hubVNetConfig.name
    remoteVNetName: dmzSpokeVNetConfig.name
    remoteVNetId: dmzSpokeVNet.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
  dependsOn: [
    hubVNet
    dmzSpokeVNet
  ]
}

// Create VNet Peering - DMZ Spoke to Hub
module dmzToHubPeering 'modules/vnet-peering.bicep' = {
  name: 'peering-dmz-to-hub'
  scope: rg
  params: {
    localVNetName: dmzSpokeVNetConfig.name
    remoteVNetName: hubVNetConfig.name
    remoteVNetId: hubVNet.outputs.vnetId
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubVNet
    dmzSpokeVNet
  ]
}

// Deploy AKS Cluster in DMZ
module aksCluster 'modules/aks-cluster.bicep' = if (aksConfig.enabled) {
  name: 'deploy-aks-cluster'
  scope: rg
  params: {
    location: location
    aksClusterName: aksConfig.clusterName
    dnsPrefix: aksConfig.dnsPrefix
    kubernetesVersion: aksConfig.kubernetesVersion
    subnetId: dmzSpokeVNet.outputs.aksSubnetId
    nodePoolConfig: {
      name: 'systempool'
      vmSize: aksConfig.nodePoolVmSize
      count: aksConfig.nodeCount
      minCount: aksConfig.minNodeCount
      maxCount: aksConfig.maxNodeCount
      enableAutoScaling: true
    }
  }
  dependsOn: [
    dmzToHubPeering
  ]
}

// Outputs
output resourceGroupName string = rg.name
output hubVNetId string = hubVNet.outputs.vnetId
output hubFirewallName string = hubVNet.outputs.firewallName
output hubFirewallPrivateIp string = hubVNet.outputs.firewallPrivateIp
output spokeVNetIds array = [for i in range(0, length(spokeVNetConfigs)): spokeVNets[i].outputs.vnetId]
output dmzVNetId string = dmzSpokeVNet.outputs.vnetId
output dmzFirewallName string = dmzSpokeVNet.outputs.firewallName
output dmzAppGatewayName string = dmzSpokeVNet.outputs.appGatewayName
output aksClusterName string = aksConfig.enabled ? aksCluster.outputs.aksClusterName : 'Not deployed'
output aksClusterFqdn string = aksConfig.enabled ? aksCluster.outputs.aksClusterFqdn : 'Not deployed'
