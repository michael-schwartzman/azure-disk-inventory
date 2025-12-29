#!/bin/bash
# Azure OS Disks Inventory Query
# This script queries all OS disks across all resource groups in your Azure environment

echo "Fetching OS disks inventory across all resource groups..."
echo ""

# Using Azure Resource Graph for cross-RG query
az graph query -q "Resources | where type =~ 'microsoft.compute/disks' | where isnotempty(properties.osType) | project name, resourceGroup, osType = properties.osType, diskState = properties.diskState, skuName = sku.name, diskSizeGB = properties.diskSizeGB, location" --first 1000

echo ""
echo "Query completed!"
