# GCP Hub-Spoke Network - Quick Start Guide

This guide will help you quickly deploy the GCP hub-spoke network architecture.

## Prerequisites

Before you begin, ensure you have:

1. **GCP Account** with billing enabled
2. **Project** created in GCP Console
3. **gcloud CLI** installed ([Download](https://cloud.google.com/sdk/docs/install))
4. **Terraform** installed ([Download](https://www.terraform.io/downloads.html))
5. **Required permissions**: Project Editor or Owner role

## Quick Deployment (5 minutes)

### Step 1: Authenticate with GCP (1 minute)

```bash
# Login to GCP
gcloud auth login

# Set up application default credentials for Terraform
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Enable Required APIs (1 minute)

```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable Service Networking API
gcloud services enable servicenetworking.googleapis.com

# Enable Kubernetes Engine API
gcloud services enable container.googleapis.com

# Enable Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com
```

### Step 3: Configure Terraform (1 minute)

```bash
# Navigate to the GCP directory
cd GCP

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your project ID
# Replace 'your-gcp-project-id' with your actual project ID
sed -i 's/your-gcp-project-id/YOUR_PROJECT_ID/g' terraform.tfvars
```

Or manually edit `terraform.tfvars`:
```hcl
project_id = "YOUR_PROJECT_ID"
region     = "us-east1"
```

### Step 4: Deploy (2-3 minutes)

```bash
# Make the deployment script executable (if not already)
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

The script will:
1. Initialize Terraform
2. Validate the configuration
3. Show you a plan of what will be created
4. Ask for confirmation before deploying
5. Create all resources

**Alternative**: Manual Terraform commands
```bash
terraform init
terraform plan
terraform apply
```

## What Gets Deployed?

After deployment completes, you'll have:

### Networks
- ✅ 1 Hub VPC (10.0.0.0/16)
- ✅ 2 Spoke VPCs (10.1.0.0/16, 10.2.0.0/16)
- ✅ 1 DMZ VPC (10.3.0.0/16)

### Container Platform
- ✅ GKE cluster in DMZ (when enabled)
- ✅ Sample Hello World app ready to deploy

### Security
- ✅ Cloud NAT for centralized egress
- ✅ Cloud Armor WAF for web protection
- ✅ Firewall rules for traffic control
- ✅ VPC peering for secure communication

### Load Balancing
- ✅ HTTPS Load Balancer in DMZ
- ✅ Backend services configured

## Verify Deployment

### Check VPC Networks
```bash
gcloud compute networks list
```

Expected output:
```
NAME            SUBNET_MODE  BGP_ROUTING_MODE  IPV4_RANGE  GATEWAY_IPV4
vpc-hub         CUSTOM       GLOBAL
vpc-spoke1      CUSTOM       GLOBAL
vpc-spoke2      CUSTOM       GLOBAL
vpc-dmz-spoke   CUSTOM       GLOBAL
```

### Check Subnets
```bash
gcloud compute networks subnets list --sort-by=NETWORK
```

### Check VPC Peering
```bash
gcloud compute networks peerings list
```

### Check Cloud NAT
```bash
gcloud compute routers nats list --router=vpc-hub-router --region=us-east1
```

### Check Load Balancer
```bash
gcloud compute forwarding-rules list
```

### View Terraform Outputs
```bash
terraform output
```

## Next Steps

### 1. Deploy Hello World App to GKE

After the infrastructure deployment completes:

```bash
# Get GKE credentials
gcloud container clusters get-credentials gke-dmz-cluster --region us-east1 --project YOUR_PROJECT_ID

# Verify connection
kubectl cluster-info

# Deploy the Hello World app
kubectl apply -f k8s-manifests/hello-world.yaml

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Get the external IP (may take a few minutes)
kubectl get service hello-world --watch
```

Once the LoadBalancer service has an external IP, access the app at:
```
http://<EXTERNAL-IP>
```

See [k8s-manifests/README.md](k8s-manifests/README.md) for more details.

### 2. Add Compute Instances

Deploy VMs to test connectivity:

```bash
# Create a VM in spoke1
gcloud compute instances create test-vm-spoke1 \
  --zone=us-east1-b \
  --machine-type=e2-micro \
  --network-interface=subnet=vpc-spoke1-workload-subnet,no-address \
  --metadata=enable-oslogin=TRUE

# Create a VM in spoke2
gcloud compute instances create test-vm-spoke2 \
  --zone=us-east1-b \
  --machine-type=e2-micro \
  --network-interface=subnet=vpc-spoke2-workload-subnet,no-address \
  --metadata=enable-oslogin=TRUE
```

### 2. Test Connectivity

```bash
# SSH to spoke1 VM using IAP
gcloud compute ssh test-vm-spoke1 --zone=us-east1-b --tunnel-through-iap

# Ping spoke2 VM (get IP first)
SPOKE2_IP=$(gcloud compute instances describe test-vm-spoke2 \
  --zone=us-east1-b --format='get(networkInterfaces[0].networkIP)')

ping -c 3 $SPOKE2_IP
```

### 3. Configure Cloud Armor Rules

Add custom security rules to Cloud Armor:

```bash
# List current Cloud Armor policies
gcloud compute security-policies list

# Add a rule to block specific IP
gcloud compute security-policies rules create 1000 \
  --security-policy=vpc-dmz-spoke-cloud-armor-policy \
  --expression="origin.ip == '1.2.3.4'" \
  --action=deny-403
```

### 4. Configure Load Balancer Backend

Add backend instances to the load balancer:

```bash
# Create instance template
gcloud compute instance-templates create lb-backend-template \
  --machine-type=e2-micro \
  --network-interface=subnet=vpc-dmz-spoke-workload-subnet \
  --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install -y apache2
echo "Hello from DMZ" > /var/www/html/index.html'

# Create instance group
gcloud compute instance-groups managed create lb-backend-group \
  --base-instance-name=lb-backend \
  --template=lb-backend-template \
  --size=2 \
  --zone=us-east1-b
```

## Cost Management

### View Current Costs
```bash
# View billing for the project
gcloud billing projects describe YOUR_PROJECT_ID
```

### Set Budget Alerts
Create budget alerts in GCP Console:
1. Go to Billing → Budgets & alerts
2. Create budget
3. Set threshold alerts (e.g., 50%, 90%, 100%)

### Estimated Monthly Costs
- **Hub VPC**: ~$45 (Cloud NAT)
- **DMZ VPC**: ~$18-25 (Load Balancer + Cloud Armor)
- **GKE Cluster**: ~$75 (cluster management fee) + node costs
- **GKE Nodes**: ~$25-50 (2x e2-medium instances)
- **Total**: ~$163-195/month + data transfer

## Cleanup

### Option 1: Destroy Everything (Recommended for Testing)
```bash
terraform destroy
```

Type `yes` when prompted.

### Option 2: Delete Specific Resources
```bash
# Delete instances first
gcloud compute instances delete test-vm-spoke1 --zone=us-east1-b --quiet
gcloud compute instances delete test-vm-spoke2 --zone=us-east1-b --quiet

# Then run terraform destroy
terraform destroy
```

### Option 3: Manual Cleanup
```bash
# Delete VPC networks (will fail if resources exist)
gcloud compute networks delete vpc-spoke1 --quiet
gcloud compute networks delete vpc-spoke2 --quiet
gcloud compute networks delete vpc-dmz-spoke --quiet
gcloud compute networks delete vpc-hub --quiet
```

## Troubleshooting

### Issue: API Not Enabled
**Error**: `API [compute.googleapis.com] not enabled` or similar API errors

**Solution**:
```bash
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### Issue: Insufficient Permissions
**Error**: `Permission denied`

**Solution**: Ensure you have Project Editor or Owner role
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

### Issue: Quota Exceeded
**Error**: `Quota exceeded`

**Solution**: Request quota increase in GCP Console
1. Go to IAM & Admin → Quotas
2. Filter by service (e.g., Compute Engine)
3. Request increase

### Issue: VPC Peering Failed
**Error**: `Peering failed to establish`

**Solution**: Check for:
- Overlapping IP ranges
- VPC peering already exists
- VPC doesn't exist yet

### Issue: Terraform State Lock
**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Getting Help

- **GCP Documentation**: https://cloud.google.com/docs
- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **Community**: https://cloud.google.com/community

## Additional Resources

- [GCP VPC Best Practices](https://cloud.google.com/vpc/docs/best-practices)
- [Cloud Armor Best Practices](https://cloud.google.com/armor/docs/security-policy-concepts)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
