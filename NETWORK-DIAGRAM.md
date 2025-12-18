# Network Diagram

```
                                    Internet
                                       |
                    +------------------+------------------+
                    |                                     |
                    v                                     v
        +-----------------------+          +------------------------+
        | Hub Firewall          |          | App Gateway (WAF)      |
        | Public IP: x.x.x.x    |          | Public IP: y.y.y.y     |
        | Private IP: 10.0.1.4  |          | DMZ Spoke              |
        +-----------+-----------+          +------------------------+
                    |                                     |
                    |                                     v
        +-----------v------------+          +------------------------+
        | Hub VNet               |          | DMZ Firewall           |
        | 10.0.0.0/16            |          | Private IP: 10.3.1.4   |
        |                        |          +------------+-----------+
        | Subnets:               |                       |
        | - Firewall: 10.0.1.0/24|                       |
        | - Gateway:  10.0.2.0/24|          +------------v-----------+
        | - Bastion:  10.0.3.0/24|          | DMZ VNet               |
        +-----------+------------+          | 10.3.0.0/16            |
                    |                       |                        |
                    |                       | Subnets:               |
        +-----------+------------+          | - Firewall: 10.3.1.0/24|
        |   VNet Peering         |          | - AppGW:    10.3.2.0/24|
        |   (Hub to Spokes)      |          | - Workload: 10.3.3.0/24|
        +-----------+------------+          +------------------------+
                    |                                     ^
           +--------+--------+                            |
           |                 |                            |
           v                 v                 +----------+-----------+
+----------+---------+  +----+----------+      |   VNet Peering       |
| Spoke 1 VNet       |  | Spoke 2 VNet  |      |   (Hub to DMZ)       |
| 10.1.0.0/16        |  | 10.2.0.0/16   |      +----------------------+
|                    |  |               |
| Subnets:           |  | Subnets:      |
| - Workload:        |  | - Workload:   |
|   10.1.1.0/24      |  |   10.2.1.0/24 |
|   (UDR → Hub FW)   |  |   (UDR → Hub FW)|
+--------------------+  +---------------+
```

## Traffic Flow Patterns

### 1. East/West Traffic (Spoke-to-Spoke)
```
Spoke 1 (10.1.1.x)
    |
    | Route: 0.0.0.0/0 → 10.0.1.4
    v
Hub Firewall (10.0.1.4)
    |
    | Inspection & Routing
    v
Spoke 2 (10.2.1.x)
```

### 2. North/South Traffic - Outbound (Spoke to Internet)
```
Spoke Workload
    |
    | Route: 0.0.0.0/0 → 10.0.1.4
    v
Hub Firewall (10.0.1.4)
    |
    | NAT & Inspection
    v
Internet
```

### 3. North/South Traffic - Inbound (Internet to DMZ)
```
Internet
    |
    | HTTPS/HTTP
    v
App Gateway WAF (10.3.2.x)
    |
    | WAF Rules (OWASP 3.2)
    v
DMZ Firewall (10.3.1.4)
    |
    | Additional Inspection
    v
DMZ Workload (10.3.3.x)
```

### 4. DMZ to Other Spokes
```
DMZ Workload (10.3.3.x)
    |
    | Route: 0.0.0.0/0 → 10.0.1.4
    v
Hub Firewall (10.0.1.4)
    |
    | Inspection & Routing
    v
Spoke 1 or Spoke 2
```

## Security Layers

```
Layer 1: VNet Isolation
    ↓
Layer 2: VNet Peering (Controlled Access)
    ↓
Layer 3: User-Defined Routes (Force Tunneling)
    ↓
Layer 4: Hub Azure Firewall (Central Policy)
    ↓
Layer 5: DMZ Firewall (Additional Protection)
    ↓
Layer 6: Application Gateway WAF (Web Protection)
    ↓
Workload
```

## Resource Naming Convention

| Resource Type | Naming Pattern | Example |
|--------------|----------------|---------|
| Resource Group | rg-{purpose} | rg-hub-spoke-network |
| Virtual Network | vnet-{name} | vnet-hub, vnet-spoke1 |
| Subnet | snet-{purpose} | snet-workload |
| Azure Firewall | afw-{vnet-name} | afw-vnet-hub |
| Firewall Policy | afwp-{vnet-name} | afwp-vnet-hub |
| Public IP | pip-{resource}-{purpose} | pip-vnet-hub-firewall |
| Route Table | rt-{vnet}-{subnet} | rt-vnet-spoke1-workload |
| App Gateway | agw-{vnet-name} | agw-vnet-dmz-spoke |

## IP Address Allocation

### Hub VNet (10.0.0.0/16)
- 10.0.1.0/24 - Azure Firewall Subnet (256 IPs)
  - 10.0.1.4 - Hub Firewall Primary IP
- 10.0.2.0/24 - Gateway Subnet (256 IPs)
- 10.0.3.0/24 - Bastion Subnet (256 IPs)
- 10.0.4.0/22 - Reserved for future subnets (1024 IPs)

### Spoke 1 VNet (10.1.0.0/16)
- 10.1.1.0/24 - Workload Subnet (256 IPs)
- 10.1.2.0/23 - Reserved for future subnets (512 IPs)

### Spoke 2 VNet (10.2.0.0/16)
- 10.2.1.0/24 - Workload Subnet (256 IPs)
- 10.2.2.0/23 - Reserved for future subnets (512 IPs)

### DMZ Spoke VNet (10.3.0.0/16)
- 10.3.1.0/24 - Azure Firewall Subnet (256 IPs)
  - 10.3.1.4 - DMZ Firewall Primary IP
- 10.3.2.0/24 - Application Gateway Subnet (256 IPs)
- 10.3.3.0/24 - Workload Subnet (256 IPs)
- 10.3.4.0/22 - Reserved for future subnets (1024 IPs)

## Peering Configuration Matrix

| From/To | Hub | Spoke 1 | Spoke 2 | DMZ |
|---------|-----|---------|---------|-----|
| Hub | - | ✓ | ✓ | ✓ |
| Spoke 1 | ✓ | - | via Hub | via Hub |
| Spoke 2 | ✓ | via Hub | - | via Hub |
| DMZ | ✓ | via Hub | via Hub | - |

All inter-spoke traffic is forced through the hub firewall via User-Defined Routes.

## Deployment Sequence

```
1. Create Resource Group
        ↓
2. Deploy Hub VNet
        ↓
3. Deploy Hub Firewall
        ↓
4. Deploy Spoke VNets (in parallel)
        ↓
5. Deploy DMZ VNet
        ↓
6. Deploy DMZ Firewall & App Gateway
        ↓
7. Create VNet Peerings (bidirectional)
        ↓
8. Configure Route Tables
        ↓
9. Validate Connectivity
```

Estimated deployment time: 15-20 minutes
