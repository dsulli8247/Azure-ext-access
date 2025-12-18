#!/bin/bash

# Azure Hub-Spoke Network Deployment Script
# This script deploys the hub-spoke network architecture using Azure Bicep

set -e  # Exit on any error

echo "=================================================="
echo "Azure Hub-Spoke Network Deployment"
echo "=================================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "You are not logged in to Azure. Please login..."
    az login
fi

# Get current subscription
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo ""
echo "Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""
read -p "Do you want to use this subscription? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Please set your desired subscription using: az account set --subscription <subscription-id>"
    exit 1
fi

# Set deployment location (default from parameters file)
LOCATION="${1:-eastus}"
DEPLOYMENT_NAME="hub-spoke-deployment-$(date +%Y%m%d-%H%M%S)"

echo ""
echo "=================================================="
echo "Deployment Configuration"
echo "=================================================="
echo "Location: $LOCATION"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the deployment? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Run what-if to preview changes
echo ""
echo "Running what-if analysis to preview changes..."
echo ""
az deployment sub what-if \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME-whatif" \
  --template-file main.bicep \
  --parameters main.parameters.json

echo ""
read -p "Do you want to proceed with the actual deployment? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy
echo ""
echo "=================================================="
echo "Starting deployment..."
echo "=================================================="
echo ""

az deployment sub create \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file main.bicep \
  --parameters main.parameters.json

# Check deployment status
if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "Deployment completed successfully!"
    echo "=================================================="
    echo ""
    echo "Deployment outputs:"
    az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs -o json
    echo ""
    echo "To view resources created, run:"
    echo "  az resource list --resource-group rg-hub-spoke-network -o table"
else
    echo ""
    echo "=================================================="
    echo "Deployment failed!"
    echo "=================================================="
    echo ""
    echo "Check deployment logs with:"
    echo "  az deployment sub show --name $DEPLOYMENT_NAME"
    exit 1
fi
