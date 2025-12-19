#!/bin/bash

# GCP Hub-Spoke Network Deployment Script
# This script deploys the hub-spoke network architecture using Terraform

set -euo pipefail  # Exit on any error, undefined variables, and pipe failures

echo "=================================================="
echo "GCP Hub-Spoke Network Deployment"
echo "=================================================="
echo ""

# Check if gcloud CLI is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed. Please install it from https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed. Please install it from https://www.terraform.io/downloads.html"
    exit 1
fi

# Check if user is logged in
echo "Checking gcloud login status..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "You are not logged in to GCP. Please login..."
    gcloud auth login
    gcloud auth application-default login
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo "No project is set. Please set your project using: gcloud config set project <project-id>"
    exit 1
fi

echo ""
echo "Current project: $PROJECT_ID"
echo ""
read -p "Do you want to use this project? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Please set your desired project using: gcloud config set project <project-id>"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo ""
    echo "terraform.tfvars not found. Creating from example..."
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        echo "Please edit terraform.tfvars with your project ID and settings"
        exit 1
    else
        echo "Error: terraform.tfvars.example not found"
        exit 1
    fi
fi

# Set region (default from variables)
REGION="${1:-us-east1}"

echo ""
echo "=================================================="
echo "Deployment Configuration"
echo "=================================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the deployment? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Initialize Terraform
echo ""
echo "=================================================="
echo "Initializing Terraform..."
echo "=================================================="
echo ""
terraform init

# Validate Terraform configuration
echo ""
echo "=================================================="
echo "Validating Terraform configuration..."
echo "=================================================="
echo ""
terraform validate

# Run Terraform plan to preview changes
echo ""
echo "=================================================="
echo "Running Terraform plan to preview changes..."
echo "=================================================="
echo ""
terraform plan -out=tfplan

echo ""
read -p "Do you want to proceed with the actual deployment? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply Terraform
echo ""
echo "=================================================="
echo "Starting deployment..."
echo "=================================================="
echo ""

terraform apply tfplan

# Check deployment status
if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "Deployment completed successfully!"
    echo "=================================================="
    echo ""
    echo "Deployment outputs:"
    terraform output
    echo ""
    echo "To view resources created, run:"
    echo "  gcloud compute networks list --project=$PROJECT_ID"
    echo "  gcloud compute firewall-rules list --project=$PROJECT_ID"
    
    # Clean up plan file
    rm -f tfplan
else
    echo ""
    echo "=================================================="
    echo "Deployment failed!"
    echo "=================================================="
    echo ""
    echo "Check Terraform logs for details"
    rm -f tfplan
    exit 1
fi
