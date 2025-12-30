#!/bin/bash
# Troubleshooting script for azure-disk-inventory.sh

echo "=========================================="
echo "Azure Disk Inventory - Troubleshooting"
echo "=========================================="
echo ""

echo "1. Checking Azure CLI..."
if ! command -v az &> /dev/null; then
    echo "❌ ERROR: Azure CLI (az) not found"
    echo "   Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
else
    echo "✅ Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
fi
echo ""

echo "2. Checking jq..."
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: jq not found"
    echo "   Install: brew install jq  (macOS)"
    echo "           sudo apt-get install jq  (Ubuntu/Debian)"
    exit 1
else
    echo "✅ jq found: $(jq --version)"
fi
echo ""

echo "3. Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "❌ ERROR: Not logged in to Azure"
    echo "   Run: az login"
    exit 1
else
    echo "✅ Logged in to Azure"
    echo ""
    echo "Current subscription:"
    az account show --query "{Name:name, ID:id, State:state}" -o table
fi
echo ""

echo "4. Checking for VMSS..."
vmss_count=$(az vmss list --query "length([])" -o tsv 2>/dev/null)
if [ "$vmss_count" = "0" ] || [ -z "$vmss_count" ]; then
    echo "⚠️  WARNING: No VMSS found in current subscription"
    echo "   This is why VMSS sections are empty"
    echo ""
    echo "   Available subscriptions:"
    az account list --query "[].{Name:name, ID:id, State:state}" -o table
    echo ""
    echo "   To switch subscription: az account set --subscription \"SUBSCRIPTION_NAME\""
else
    echo "✅ Found $vmss_count VMSS in current subscription"
    echo ""
    echo "VMSS list:"
    az vmss list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o table
fi
echo ""

echo "5. Checking for standalone VM disks..."
disk_count=$(az graph query -q "Resources | where type =~ 'microsoft.compute/disks' | where isnotempty(properties.osType) | summarize count()" --query "data[0].count_" -o tsv 2>/dev/null)
if [ -z "$disk_count" ]; then
    echo "⚠️  WARNING: Could not query disks (Resource Graph might not be available)"
else
    echo "✅ Found $disk_count standalone OS disks"
fi
echo ""

echo "=========================================="
echo "Troubleshooting Summary"
echo "=========================================="

if [ "$vmss_count" = "0" ] || [ -z "$vmss_count" ]; then
    echo ""
    echo "LIKELY ISSUE: No VMSS in current subscription"
    echo ""
    echo "SOLUTION:"
    echo "1. List all your subscriptions: az account list -o table"
    echo "2. Switch to correct subscription: az account set --subscription \"NAME_OR_ID\""
    echo "3. Run the script again: ./azure-disk-inventory.sh"
else
    echo ""
    echo "✅ Environment looks good!"
    echo "   Try running: ./azure-disk-inventory.sh"
fi
echo ""
