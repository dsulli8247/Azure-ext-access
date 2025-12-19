// Azure Kubernetes Service (AKS) Cluster module

@description('Azure region for resources')
param location string

@description('AKS cluster name')
param aksClusterName string

@description('Kubernetes version')
param kubernetesVersion string = '1.28.0'

@description('DNS prefix for AKS cluster')
param dnsPrefix string

@description('Subnet ID for AKS nodes')
param subnetId string

@description('Node pool configuration')
param nodePoolConfig object = {
  name: 'systempool'
  vmSize: 'Standard_DS2_v2'
  count: 2
  minCount: 1
  maxCount: 3
  enableAutoScaling: true
}

@description('Enable RBAC')
param enableRBAC bool = true

@description('Network plugin')
param networkPlugin string = 'azure'

@description('Network policy')
param networkPolicy string = 'azure'

@description('Service CIDR')
param serviceCidr string = '10.240.0.0/16'

@description('DNS service IP')
param dnsServiceIP string = '10.240.0.10'

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    agentPoolProfiles: [
      {
        name: nodePoolConfig.name
        count: nodePoolConfig.count
        minCount: nodePoolConfig.minCount
        maxCount: nodePoolConfig.maxCount
        vmSize: nodePoolConfig.vmSize
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: nodePoolConfig.enableAutoScaling
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        maxPods: 110
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'standard'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
  }
}

// Outputs
output aksClusterId string = aksCluster.id
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output aksIdentityPrincipalId string = aksCluster.identity.principalId
output aksIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
