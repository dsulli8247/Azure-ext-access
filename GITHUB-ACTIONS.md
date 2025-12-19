# GitHub Actions Configuration Guide

This guide explains how to configure GitHub Actions secrets and variables for automated deployment of Azure and GCP infrastructure.

## Table of Contents

- [Overview](#overview)
- [Azure Configuration](#azure-configuration)
- [GCP Configuration](#gcp-configuration)
- [Environment Configuration](#environment-configuration)
- [Testing the Workflows](#testing-the-workflows)
- [Troubleshooting](#troubleshooting)

## Overview

This repository includes two GitHub Actions workflows:

1. **Azure Infrastructure Deployment** (`azure-deploy.yml`)
   - Validates Bicep templates
   - Deploys Azure hub-spoke network
   - Deploys AKS cluster (optional)
   - Deploys sample Hello World application

2. **GCP Infrastructure Deployment** (`gcp-deploy.yml`)
   - Validates Terraform configuration
   - Deploys GCP hub-spoke network
   - Deploys GKE cluster (optional)
   - Deploys sample Hello World application

## Azure Configuration

### Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed locally (for initial setup)

### Step 1: Create an Azure Service Principal

Create a service principal with Contributor access to your subscription:

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription <your-subscription-id>

# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

This command will output JSON credentials. **Save this output** - you'll need it in the next step.

The output will look like this:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### Step 2: Add Azure Secret to GitHub

1. Go to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_CREDENTIALS`
5. Value: Paste the entire JSON output from Step 1
6. Click **Add secret**

### Step 3: Verify Azure Configuration

The Azure workflow will automatically use the `AZURE_CREDENTIALS` secret. The deployment will:

- Create resources in the `eastus` region (configurable in workflow)
- Create a resource group named `rg-hub-spoke-network`
- Deploy all infrastructure defined in `main.bicep`

### Azure Secrets Summary

| Secret Name | Description | Required |
|------------|-------------|----------|
| `AZURE_CREDENTIALS` | Service principal credentials (JSON) | ✅ Yes |

## GCP Configuration

### Prerequisites

- GCP project with billing enabled
- gcloud CLI installed locally (for initial setup)

### Step 1: Create a GCP Service Account

Create a service account with necessary permissions:

```bash
# Login to GCP
gcloud auth login

# Set your project
gcloud config set project <your-project-id>

# Create service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

# Get the service account email
SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:GitHub Actions Service Account" \
  --format="value(email)")

echo "Service Account Email: $SA_EMAIL"
```

### Step 2: Grant Permissions to Service Account

Grant the necessary roles for infrastructure deployment:

```bash
# Project Editor role (comprehensive access)
gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/editor"

# Kubernetes Engine Admin (for GKE)
gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/container.admin"

# Compute Network Admin (for VPC)
gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/compute.networkAdmin"

# Service Account User (for creating resources)
gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"
```

### Step 3: Create and Download Service Account Key

```bash
# Create JSON key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=$SA_EMAIL

# Display the key (you'll copy this)
cat github-actions-key.json
```

**Important**: Store this key securely and delete the local copy after adding it to GitHub secrets.

### Step 4: Enable Required APIs

Enable the necessary GCP APIs:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### Step 5: Add GCP Secrets to GitHub

1. Go to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

**Secret 1: GCP_CREDENTIALS**
- Click **New repository secret**
- Name: `GCP_CREDENTIALS`
- Value: Paste the entire contents of `github-actions-key.json`
- Click **Add secret**

**Secret 2: GCP_PROJECT_ID**
- Click **New repository secret**
- Name: `GCP_PROJECT_ID`
- Value: Your GCP project ID (e.g., `my-project-123456`)
- Click **Add secret**

### Step 6: Clean Up Local Key

After adding the key to GitHub, delete the local copy:

```bash
rm github-actions-key.json
```

### GCP Secrets Summary

| Secret Name | Description | Required |
|------------|-------------|----------|
| `GCP_CREDENTIALS` | Service account key (JSON) | ✅ Yes |
| `GCP_PROJECT_ID` | GCP project ID | ✅ Yes |

## Environment Configuration

Both workflows support multiple environments (dev, staging, production) using GitHub Environments.

### Setting Up Environments

1. Go to **Settings** → **Environments** in your repository
2. Click **New environment**
3. Create environments: `dev`, `staging`, `production`
4. (Optional) Add protection rules:
   - Required reviewers for production
   - Wait timer before deployment
   - Deployment branches

### Environment Variables

You can override default values per environment:

**For Azure:**
- `AZURE_RESOURCE_GROUP`: Resource group name
- `AZURE_LOCATION`: Azure region

**For GCP:**
- `GCP_REGION`: GCP region
- `TF_VERSION`: Terraform version

## Testing the Workflows

### Azure Deployment

#### Manual Trigger

1. Go to **Actions** tab in GitHub
2. Select **Azure Infrastructure Deployment**
3. Click **Run workflow**
4. Choose:
   - Environment: `dev`, `staging`, or `production`
   - Deploy AKS: `true` or `false`
5. Click **Run workflow**

#### Automatic Trigger

The workflow automatically runs when you push changes to:
- `main.bicep`
- Files in `modules/` directory
- `main.parameters.json`
- The workflow file itself

### GCP Deployment

#### Manual Trigger

1. Go to **Actions** tab in GitHub
2. Select **GCP Infrastructure Deployment**
3. Click **Run workflow**
4. Choose:
   - Environment: `dev`, `staging`, or `production`
   - Deploy GKE: `true` or `false`
5. Click **Run workflow**

#### Automatic Trigger

The workflow automatically runs when you push changes to:
- Files in `GCP/` directory
- The workflow file itself

## Workflow Features

### Azure Workflow

1. **Validation**: Validates Bicep templates
2. **Planning**: Shows what-if analysis of changes
3. **Deployment**: Deploys infrastructure
4. **AKS Application**: Deploys Hello World app to AKS
5. **Outputs**: Displays deployment summary

### GCP Workflow

1. **Validation**: Validates Terraform configuration
2. **Planning**: Shows Terraform plan
3. **Deployment**: Deploys infrastructure
4. **GKE Application**: Deploys Hello World app to GKE
5. **Outputs**: Displays deployment summary

## Troubleshooting

### Azure Issues

**Issue**: "Authentication failed"
```
Error: AADSTS700016: Application with identifier 'xxx' was not found
```
**Solution**: Verify `AZURE_CREDENTIALS` secret is correctly formatted JSON and the service principal exists.

**Issue**: "Insufficient permissions"
```
Error: The client 'xxx' does not have authorization to perform action
```
**Solution**: Ensure the service principal has Contributor role on the subscription.

**Issue**: "Quota exceeded"
```
Error: Operation could not be completed as it results in exceeding approved quota
```
**Solution**: Request quota increase in Azure Portal or reduce resource sizes.

### GCP Issues

**Issue**: "Invalid credentials"
```
Error: google: could not find default credentials
```
**Solution**: Verify `GCP_CREDENTIALS` secret contains valid service account key JSON.

**Issue**: "API not enabled"
```
Error: Compute Engine API has not been used in project xxx
```
**Solution**: Enable required APIs:
```bash
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

**Issue**: "Permission denied"
```
Error: Required 'compute.networks.create' permission
```
**Solution**: Ensure service account has necessary IAM roles (Editor, Container Admin, etc.).

### General Issues

**Issue**: Workflow not triggering on push
**Solution**: 
- Check that you're pushing to the `main` branch
- Verify the file paths match the workflow triggers
- Check GitHub Actions is enabled for your repository

**Issue**: Workflow fails at kubectl commands
**Solution**:
- Verify cluster was deployed successfully
- Check that credentials are being fetched correctly
- Ensure cluster is in running state

## Security Best Practices

1. **Rotate Credentials**: Regularly rotate service principal and service account keys
2. **Use Environments**: Require approvals for production deployments
3. **Limit Permissions**: Grant minimum required permissions to service accounts
4. **Monitor Activity**: Review deployment logs regularly
5. **Secure Secrets**: Never commit credentials to the repository
6. **Branch Protection**: Protect main branch to prevent unauthorized changes

## Next Steps

After configuring secrets and running your first deployment:

1. **Monitor Costs**: Set up billing alerts in Azure and GCP
2. **Configure Monitoring**: Enable Azure Monitor / GCP Cloud Monitoring
3. **Set Up Alerts**: Create alerts for deployment failures
4. **Review Resources**: Verify all resources were created correctly
5. **Test Applications**: Access deployed Hello World applications
6. **Customize Deployments**: Modify parameters for your use case

## Additional Resources

### Azure
- [Azure Service Principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [GitHub Actions for Azure](https://github.com/Azure/actions)

### GCP
- [Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)
- [GitHub Actions for GCP](https://github.com/google-github-actions)

### GitHub Actions
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
