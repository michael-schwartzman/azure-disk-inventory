# Azure Disk Inventory

A collection of scripts to inventory and analyze OS disks in Azure environments, including both standalone VMs and Virtual Machine Scale Sets (VMSS).

## Features

- 📊 Complete inventory of all OS disks across all resource groups
- 🔍 Separate sections for VMSS with managed disks, VMSS with ephemeral disks, and standalone VMs
- 📈 CSV export for analysis in Excel/Google Sheets
- 💾 Displays disk sizes, types, states, and total capacity
- ⚡ Identifies ephemeral vs persistent disks

## Prerequisites

- Azure CLI installed and configured (`az`)
- Python 3.x
- `jq` (for JSON parsing)
- Active Azure subscription with appropriate permissions

## Scripts

### 1. `azure-disk-inventory.sh`

**Main inventory script** - Provides complete OS disk inventory with detailed breakdown and CSV export.

#### Usage

```bash
./azure-disk-inventory.sh
```

#### Output

- **Console**: Formatted tables showing:
  - VMSS with Managed (Non-Ephemeral) OS Disks
  - VMSS with Ephemeral OS Disks
  - Standalone VM OS Disks (Non-VMSS)
  
- **CSV File**: Timestamped CSV file (`azure_os_disks_inventory_YYYYMMDD_HHMMSS.csv`) containing all disk data

#### CSV Columns

- Type (VMSS-Managed, VMSS-Ephemeral, Standalone-VM)
- Name
- Resource Group
- Instances
- OS Type
- Disk State
- Disk Type (Premium_LRS, Standard_LRS, StandardSSD_LRS)
- Disk Size (GB)
- Total Capacity (GB)
- Ephemeral (Yes/No)
- Location

### 2. `azure-os-disks-query.sh`

**Simple query script** - Quick lookup of OS disks using Azure Resource Graph.

#### Usage

```bash
./azure-os-disks-query.sh
```

## Why Separate Queries for VMSS?

Azure Resource Graph doesn't expose the `diskSizeGb` property for VMSS configurations, even though it exists in the actual resources. Therefore:

- **Standalone VM disks**: Queried via Azure Resource Graph (fast, efficient)
- **VMSS configurations**: Queried via `az vmss show` for each VMSS (gets actual disk sizes)

## Important Notes

### Ephemeral Disks

VMSS instances using **ephemeral OS disks** do NOT create managed disk resources. These disks:
- Are stored on the local VM host (temporary storage)
- Do NOT appear in `microsoft.compute/disks` resource queries
- Are lost when the VM is deallocated
- Are identified by `diffDiskSettings.option = "Local"`

### Disk States

- **Attached**: Disk is currently attached to a running VM
- **Reserved**: Disk exists but VM is deallocated
- **Unattached**: Orphaned disk, potential cleanup candidate

## Examples

### Filter by disk type in CSV

Open the CSV in Excel and filter by "Disk Type" column to find all Standard_LRS (HDD) disks.

### Find unattached disks for cleanup

Filter CSV by "Disk State" = "Unattached" to identify orphaned disks.

### Calculate total storage costs

Use the "Total Capacity (GB)" column to sum up storage across different disk types/regions.

## Troubleshooting

### "jq: command not found"

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

### "az: command not found"

Install Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

### Empty output

Ensure you're logged in to Azure:
```bash
az login
az account show
```

## License

MIT License

## Author

Created for Azure disk inventory and analysis across multiple resource groups and subscriptions.
