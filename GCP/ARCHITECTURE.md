# GCP Architecture Design Document

## Overview
This document describes the GCP hub-spoke network architecture implemented using Terraform.

## Network Topology

### Hub-Spoke Model
The implementation follows a hub-spoke network topology where:
- **Hub**: Central VPC that acts as a connection point for all spoke VPCs
- **Spokes**: Peripheral VPCs connected to the hub via VPC peering

### Benefits
1. **Centralized Security**: Centralized egress through Cloud NAT in the hub
2. **Cost Optimization**: Shared services (NAT gateway, routing) in the hub
3. **Network Isolation**: Each spoke is isolated from other spokes
4. **Scalability**: Easy to add new spokes without affecting existing ones

## Network Design

### Address Space Allocation

| VPC | Address Space | Purpose |
|-----|---------------|---------|
| Hub VPC | 10.0.0.0/16 | Central hub with shared services |
| Spoke 1 | 10.1.0.0/16 | Standard workload spoke |
| Spoke 2 | 10.2.0.0/16 | Standard workload spoke |
| DMZ Spoke | 10.3.0.0/16 | DMZ with front-end services |

### Subnet Design

#### Hub VPC (10.0.0.0/16)
- **Firewall subnet** (10.0.1.0/24): Reserved for firewall/routing services
- **Gateway subnet** (10.0.2.0/24): Reserved for VPN/Interconnect gateway
- **Bastion subnet** (10.0.3.0/24): Reserved for bastion/IAP access

#### Spoke 1 VPC (10.1.0.0/16)
- **Workload subnet** (10.1.1.0/24): Application workload subnet

#### Spoke 2 VPC (10.2.0.0/16)
- **Workload subnet** (10.2.1.0/24): Application workload subnet

#### DMZ Spoke VPC (10.3.0.0/16)
- **Firewall subnet** (10.3.1.0/24): Reserved for additional security services
- **Load Balancer subnet** (10.3.2.0/24): HTTPS Load Balancer subnet
- **Workload subnet** (10.3.3.0/24): Front-end application workload

## Traffic Flow

### East/West Traffic (Inter-Spoke)
```
Spoke 1 Workload → VPC Peering → Hub → VPC Peering → Spoke 2 Workload
```

Traffic between spokes flows through VPC peering connections via the hub.

### North/South Traffic (Internet)

#### Standard Spokes
```
Spoke Workload → Cloud NAT (Hub) → Internet
```

All egress traffic from spoke VPCs goes through the Cloud NAT in the hub VPC.

#### DMZ Spoke
```
Internet → Cloud Armor (WAF) → HTTPS Load Balancer → DMZ Workload
```

The DMZ spoke has additional protection with:
1. Cloud Armor WAF for web traffic inspection
2. HTTPS Load Balancer for traffic distribution

### Hub-to-Spoke Traffic
```
Hub → VPC Peering → Spoke
```

Direct communication via VPC peering.

## Security Architecture

### Defense in Depth

1. **Layer 1: Network Isolation**
   - VPC peering with controlled traffic flow
   - Firewall rules control traffic between VPCs

2. **Layer 2: Hub NAT Gateway**
   - Centralized egress point for all spoke traffic
   - Logging enabled for audit trail

3. **Layer 3: DMZ Protection**
   - Cloud Armor WAF with OWASP rules
   - HTTPS Load Balancer for SSL termination
   - Separate security zone for internet-facing apps

4. **Layer 4: Firewall Rules**
   - VPC-level firewall rules
   - Least privilege access
   - IAP access for SSH

### Firewall Rules

#### Hub VPC
- **Purpose**: Central traffic control for all spokes
- **Rules**: 
  - Allow internal traffic (10.0.0.0/8)
  - Allow IAP SSH (35.235.240.0/20)

#### Spoke VPCs
- **Purpose**: Workload protection
- **Rules**: 
  - Allow internal traffic (10.0.0.0/8)
  - Allow IAP SSH (35.235.240.0/20)

#### DMZ VPC
- **Purpose**: Internet-facing workload protection
- **Rules**: 
  - Allow internal traffic (10.0.0.0/8)
  - Allow HTTP/HTTPS from internet (0.0.0.0/0)
  - Allow IAP SSH (35.235.240.0/20)

### Cloud Armor (WAF)

- **Integration**: Attached to HTTPS Load Balancer backend service
- **Mode**: Allow with adaptive protection enabled
- **Rule Set**: Custom rules can be added
- **Purpose**: Protect web applications from common vulnerabilities
- **Features**: 
  - Layer 7 DDoS protection
  - OWASP ModSecurity Core Rule Set compatible
  - Custom security policies

## Routing Configuration

### Custom Routes

Each spoke VPC can have custom routes configured to:
- Route internet traffic through hub (0.0.0.0/0 → hub NAT)
- Route to other spokes through hub VPC peering

### VPC Peering Configuration

All peerings are configured with:
- **Import/Export Custom Routes**: Enabled
- This allows routing tables to propagate between VPCs

## High Availability

### Cloud NAT
- Automatically scales based on traffic
- Distributed across zones
- SLA: 99.99% (covered by VPC SLA)

### HTTPS Load Balancer
- Global load balancing
- Automatic failover
- Multi-region capable
- SLA: 99.99%

### VPC Peering
- No single point of failure
- Google backbone network
- SLA: 99.99%

## Scalability

### Adding New Spokes
To add a new spoke VPC:
1. Add configuration to `spoke_vpc_configs` array in `terraform.tfvars`
2. Run `terraform apply`
3. Automatic peering and routing setup

### Scaling Existing Resources
- Cloud NAT: Automatic scaling
- HTTPS Load Balancer: Auto-scaling, multi-region
- VPC subnets: Can be expanded (with planning)

## Cost Considerations

### Monthly Estimated Costs (USD)

| Resource | Estimated Cost |
|----------|---------------|
| Cloud NAT Gateway | ~$45 |
| HTTPS Load Balancer | ~$18 + traffic |
| Cloud Armor | ~$0-25 (based on rules) |
| VPC Peering | Data transfer charges |
| External IP Addresses | ~$8 |
| **Total** | **~$71-96/month + traffic** |

*Note: Costs are estimates and vary by region and usage*

### Cost Optimization Options
1. Use regional load balancer instead of global
2. Reduce Cloud Armor rules
3. Use Cloud NAT with fewer IP addresses
4. Consolidate VPCs for dev/test environments

## Azure to GCP Feature Mapping

### Component Comparison

| Azure Component | GCP Equivalent | Notes |
|----------------|----------------|-------|
| Virtual Network (VNet) | Virtual Private Cloud (VPC) | Core network construct |
| Azure Firewall | Cloud NAT + Firewall Rules | GCP uses distributed firewall rules instead of dedicated firewall appliances |
| Application Gateway with WAF | HTTPS Load Balancer + Cloud Armor | Cloud Armor provides WAF capabilities for Load Balancer |
| Azure Kubernetes Service (AKS) | Google Kubernetes Engine (GKE) | Managed Kubernetes services |
| VNet Peering | VPC Peering | Direct network connectivity between networks |
| User-Defined Routes (UDR) | Custom Routes | Route table customization |
| Network Security Groups (NSG) | Firewall Rules | Subnet/instance-level security |
| Azure Bastion | Identity-Aware Proxy (IAP) | Secure remote access without public IPs |
| NAT Gateway | Cloud NAT | Managed NAT service for outbound connectivity |
| Public IP Address | External IP Address | Static or ephemeral public IPs |
| Azure Firewall Policy | Cloud Armor Security Policy | Centralized security policy management |

### Key Architectural Differences

1. **Firewall Architecture**: 
   - **Azure**: Uses dedicated Azure Firewall appliances (Standard/Premium tiers) deployed in specific subnets
   - **GCP**: Uses distributed VPC-level firewall rules with Cloud NAT for egress

2. **NAT Gateway**:
   - **Azure**: Azure Firewall includes NAT functionality; separate NAT Gateway also available
   - **GCP**: Cloud NAT is a separate managed service for outbound connectivity

3. **WAF Integration**:
   - **Azure**: WAF is integrated into Application Gateway as part of the service
   - **GCP**: Cloud Armor attaches to Load Balancer backend services

4. **Routing**:
   - **Azure**: Uses route tables with next-hop virtual appliance IP addresses for traffic steering
   - **GCP**: VPC peering automatically handles routing; custom routes available for advanced scenarios

5. **Network Architecture**:
   - **Azure**: Explicit hub-spoke model with route tables forcing traffic through hub firewall
   - **GCP**: VPC peering-based model with automatic route propagation and Cloud NAT for centralized egress

Both implementations achieve the same security posture and network isolation, but use different cloud-native mechanisms appropriate to each platform.

## Monitoring and Logging

### Recommended Monitoring
1. **VPC Flow Logs**
   - Enable on all subnets
   - Send to Cloud Logging
   - Analyze traffic patterns

2. **Cloud NAT Logs**
   - Monitor NAT gateway usage
   - Track egress traffic
   - Detect anomalies

3. **Load Balancer Logs**
   - Access logs
   - Cloud Armor logs
   - Backend health

4. **Firewall Logs**
   - Log denied connections
   - Monitor rule effectiveness

### Key Metrics
- NAT gateway connection count
- Load Balancer request rate
- Cloud Armor rule hits
- VPC peering bandwidth

## Compliance

### Security Standards
- Network segmentation (PCI-DSS requirement)
- Defense in depth (NIST framework)
- Traffic inspection (ISO 27001)

### Audit Trail
- All infrastructure changes tracked in Terraform state
- Cloud Audit Logs for resource changes
- VPC Flow Logs for traffic analysis

## Future Enhancements

### Phase 2 Improvements
1. Add Cloud VPN or Cloud Interconnect in hub for hybrid connectivity
2. Implement Private Service Connect
3. Add Cloud IDS (Intrusion Detection System)
4. Configure advanced Cloud Armor rules
5. Add DDoS protection
6. Implement Organization Policies

### Advanced Security
1. Security Command Center integration
2. Cloud Armor rate limiting
3. Custom threat intelligence
4. SSL/TLS policies
5. Certificate management with Certificate Manager

### Automation
1. CI/CD pipeline for infrastructure deployment
2. Automated policy updates
3. Cost monitoring and alerts
4. Compliance scanning

## References

- [GCP VPC Network Overview](https://cloud.google.com/vpc/docs/vpc)
- [Cloud NAT Documentation](https://cloud.google.com/nat/docs/overview)
- [Cloud Armor Documentation](https://cloud.google.com/armor/docs)
- [VPC Peering](https://cloud.google.com/vpc/docs/vpc-peering)
- [HTTPS Load Balancer](https://cloud.google.com/load-balancing/docs/https)
