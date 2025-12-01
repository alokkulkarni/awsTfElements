#!/bin/bash
set -e

# Script to auto-deploy contact flows locally
# Usage: ./deploy_flows.sh

echo "🚀 Starting Contact Flow Auto-Deployment..."

cd connect_nova_sonic_hybrid

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
  echo "📦 Initializing Terraform..."
  terraform init
fi

echo "🔄 Applying changes to Contact Flows..."
terraform apply -auto-approve -target=aws_connect_contact_flow.nova_sonic_ivr

echo "✅ Contact Flows Deployed Successfully!"
