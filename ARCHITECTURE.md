# Architecture Design Document

## Overview
This document describes the Azure hub-spoke network architecture implemented using Azure Bicep.

## Network Topology

### Hub-Spoke Model
The implementation follows a hub-spoke network topology where:
- **Hub**: Central VNet that acts as a connection point for all spoke VNets
- **Spokes**: Peripheral VNets connected to the hub via VNet peering

### Benefits
1. **Centralized Security**: All inter-spoke traffic flows through the hub firewall
2. **Cost Optimization**: Shared services (firewall, VPN gateway) in the hub
3. **Network Isolation**: Each spoke is isolated from other spokes
4. **Scalability**: Easy to add new spokes without affecting existing ones

## Network Design

### Address Space Allocation

| VNet | Address Space | Purpose |
|------|---------------|---------|
| Hub VNet | 10.0.0.0/16 | Central hub with shared services |
| Spoke 1 | 10.1.0.0/16 | Standard workload spoke |
| Spoke 2 | 10.2.0.0/16 | Standard workload spoke |
| DMZ Spoke | 10.3.0.0/16 | DMZ with front-end services |

### Subnet Design

#### Hub VNet (10.0.0.0/16)
- **AzureFirewallSubnet** (10.0.1.0/24): Azure Firewall for central traffic control
- **GatewaySubnet** (10.0.2.0/24): For VPN/ExpressRoute gateway (reserved)
- **AzureBastionSubnet** (10.0.3.0/24): For Azure Bastion (reserved)

#### Spoke 1 VNet (10.1.0.0/16)
- **snet-workload** (10.1.1.0/24): Application workload subnet

#### Spoke 2 VNet (10.2.0.0/16)
- **snet-workload** (10.2.1.0/24): Application workload subnet

#### DMZ Spoke VNet (10.3.0.0/16)
- **AzureFirewallSubnet** (10.3.1.0/24): DMZ firewall for additional security
- **snet-appgateway** (10.3.2.0/24): Application Gateway with WAF
- **snet-workload** (10.3.3.0/24): Front-end application workload
- **snet-aks** (10.3.4.0/24): Azure Kubernetes Service cluster nodes

## Traffic Flow

### East/West Traffic (Inter-Spoke)
```
Spoke 1 Workload → Route Table → Hub Firewall → Route Table → Spoke 2 Workload
```

All traffic between spokes is forced through the hub firewall via User-Defined Routes (UDR).

### North/South Traffic (Internet)

#### Standard Spokes
```
Spoke Workload → Hub Firewall → Internet
```

#### DMZ Spoke
```
Internet → App Gateway (WAF) → DMZ Firewall → DMZ Workload
Internet → AKS LoadBalancer → AKS Pods
```

The DMZ spoke has additional protection with:
1. Application Gateway with WAF for web traffic inspection
2. Local Azure Firewall for additional filtering
3. AKS cluster with network isolation in dedicated subnet

### AKS Traffic Flow
```
Internet → AKS LoadBalancer Service → AKS Pods (Hello World App)
```

The AKS cluster is deployed in the DMZ spoke VNet with:
- Azure CNI networking for VNet-integrated pod networking
- LoadBalancer service type for external access
- Network isolation in dedicated AKS subnet

### Hub-to-Spoke Traffic
```
Hub → VNet Peering → Spoke
```

Direct communication via VNet peering with firewall inspection.

## Security Architecture

### Defense in Depth

1. **Layer 1: Network Isolation**
   - VNet peering with controlled traffic flow
   - No direct spoke-to-spoke connectivity

2. **Layer 2: Hub Firewall**
   - All east/west traffic inspected
   - Centralized firewall policy management
   - Threat intelligence enabled

3. **Layer 3: DMZ Protection**
   - Application Gateway with WAF (OWASP 3.2)
   - DMZ-specific firewall
   - Separate security zone for internet-facing apps

4. **Layer 4: Route Tables**
   - User-Defined Routes enforce traffic flow
   - 0.0.0.0/0 routes to hub firewall
   - Prevents route bypass

### Firewall Policies

#### Hub Firewall
- **Purpose**: Central traffic control for all spokes
- **SKU**: Standard tier
- **Threat Intelligence**: Alert mode
- **Policy**: Application and network rules (to be configured)

#### DMZ Firewall
- **Purpose**: Additional protection for DMZ workloads
- **SKU**: Standard tier
- **Threat Intelligence**: Alert mode
- **Policy**: Stricter rules for internet-facing traffic

### Web Application Firewall (WAF)

- **SKU**: Application Gateway v2 with WAF
- **Capacity**: 2 instances (auto-scaling capable)
- **Mode**: Detection (recommended to switch to Prevention after tuning)
- **Rule Set**: OWASP 3.2
- **Purpose**: Protect web applications from common vulnerabilities

## Routing Configuration

### Route Tables

Each spoke workload subnet has a route table with:
```
Destination: 0.0.0.0/0
Next Hop: Virtual Appliance (Hub Firewall Private IP)
```

This ensures all internet-bound and inter-spoke traffic goes through the hub firewall.

### VNet Peering Configuration

All peerings are configured with:
- **Allow Virtual Network Access**: Enabled
- **Allow Forwarded Traffic**: Enabled
- **Allow Gateway Transit**: Enabled (hub side)
- **Use Remote Gateways**: Disabled (can be enabled when VPN gateway is added)

## High Availability

### Azure Firewall
- Deployed in a zone-redundant configuration (can be enhanced)
- Multiple backend instances for HA
- SLA: 99.95%

### Application Gateway
- Deployed with 2 instances
- Can be configured for auto-scaling
- Zone redundancy can be added
- SLA: 99.95%

### AKS Cluster
- Deployed with auto-scaling enabled (2-3 nodes by default)
- System-assigned managed identity
- Azure CNI networking for high performance
- Can be configured for zone redundancy
- SLA: 99.95% (with Uptime SLA enabled)

## Scalability

### Adding New Spokes
To add a new spoke VNet:
1. Add configuration to `spokeVNetConfigs` array in parameters
2. Redeploy the template
3. Automatic peering and routing setup

### Scaling Existing Resources
- Application Gateway: Auto-scaling (2-10 instances)
- Azure Firewall: Automatic scaling
- AKS Cluster: Auto-scaling enabled (1-3 nodes by default, configurable)
- VNet address spaces: Can be expanded (requires planning)

## Cost Considerations

### Monthly Estimated Costs (USD)

| Resource | Estimated Cost |
|----------|---------------|
| Hub Azure Firewall | ~$1,000 |
| DMZ Azure Firewall | ~$1,000 |
| Application Gateway v2 (WAF) | ~$500 |
| AKS Cluster (2 nodes, Standard_DS2_v2) | ~$150 |
| Public IP Addresses (3) | ~$10 |
| VNet Peering | ~$10-50 (based on traffic) |
| **Total** | **~$2,670/month** |

*Note: Costs are estimates and vary by region and usage*

### Cost Optimization Options
1. Use Azure Firewall Basic tier for dev/test
2. Deploy single firewall (remove DMZ firewall)
3. Use Network Security Groups instead of firewalls
4. Use smaller Application Gateway SKU
5. Disable AKS cluster when not needed (set `aksConfig.enabled: false`)
6. Use smaller VM sizes for AKS nodes
7. Reduce AKS node count for dev/test environments

## Disaster Recovery

### Backup Considerations
- VNet configurations: Infrastructure as Code (Bicep) in git
- Firewall policies: Export and version control recommended
- WAF policies: Export and version control recommended

### Regional Redundancy
- Deploy identical infrastructure in secondary region
- Use Azure Traffic Manager for failover
- Replicate firewall policies across regions

## Monitoring and Logging

### Recommended Monitoring
1. **Azure Firewall**
   - Enable diagnostic logs
   - Send to Log Analytics workspace
   - Monitor denied traffic and threats

2. **Application Gateway**
   - Enable access logs
   - Enable WAF logs
   - Monitor backend health

3. **VNet Flow Logs**
   - Enable NSG flow logs
   - Analyze traffic patterns
   - Detect anomalies

4. **AKS Monitoring**
   - Enable Container Insights
   - Monitor pod and node health
   - Track application performance
   - Configure alerts for critical metrics

### Key Metrics
- Firewall throughput
- Application Gateway request count
- WAF rule hits
- VNet peering bandwidth
- AKS node CPU and memory utilization
- AKS pod health and availability

## Compliance

### Security Standards
- Network segmentation (PCI-DSS requirement)
- Defense in depth (NIST framework)
- Traffic inspection (ISO 27001)

### Audit Trail
- All infrastructure changes tracked in git
- Azure Activity Log for resource changes
- Firewall logs for traffic analysis

## Future Enhancements

### Phase 2 Improvements
1. Add VPN Gateway in hub for hybrid connectivity
2. Add Azure Bastion for secure VM access
3. Implement network security groups (NSGs)
4. Configure firewall application and network rules
5. Add DDoS Protection Standard
6. Implement Azure Policy for governance
7. Integrate Application Gateway with AKS Ingress
8. Enable AKS Uptime SLA for production workloads
9. Configure Azure Monitor for Containers
4. Configure firewall application and network rules
5. Add DDoS Protection Standard
6. Implement Azure Policy for governance

### Advanced Security
1. Azure Sentinel integration
2. Azure Security Center
3. Custom threat intelligence feeds
4. Advanced WAF policies
5. Certificate management for SSL

### Automation
1. CI/CD pipeline for infrastructure deployment
2. Automated policy updates
3. Cost monitoring and alerts
4. Compliance scanning

## References

- [Azure Hub-Spoke Network Topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/)
- [Application Gateway WAF](https://docs.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [VNet Peering](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
