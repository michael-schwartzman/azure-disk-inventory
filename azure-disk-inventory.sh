#!/bin/bash
# Complete OS Disk Inventory - Including VMSS configurations
# This shows both managed OS disks AND VMSS OS disk configurations

# Output files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CSV_FILE="azure_os_disks_inventory_${TIMESTAMP}.csv"

# Create CSV header
echo "Type,Name,Resource Group,Instances,OS Type,Disk State,Disk Type,Disk Size (GB),Total Capacity (GB),Ephemeral,Location" > "$CSV_FILE"

echo "============================================"
echo "VMSS with Managed (Non-Ephemeral) OS Disks"
echo "============================================"

# Get VMSS list first
vmss_list=$(az vmss list --query "[].{name:name, rg:resourceGroup}" -o tsv)

# Arrays to store ephemeral and non-ephemeral VMSS
ephemeral_vmss=()
non_ephemeral_vmss=()

# Print header for non-ephemeral
printf "%-40s %-35s %-10s %-15s %-15s %-20s %-15s\n" "Name" "Resource Group" "Instances" "Disk Type" "Disk Size (GB)" "Total Capacity (GB)" "Location"
printf "%-40s %-35s %-10s %-15s %-15s %-20s %-15s\n" "----" "--------------" "---------" "---------" "--------------" "-------------------" "--------"

# Loop through each VMSS and categorize
while IFS=$'\t' read -r vmss_name rg; do
    vmss_data=$(az vmss show -n "$vmss_name" -g "$rg" --query "{Name:name, ResourceGroup:resourceGroup, Instances:sku.capacity, DiskType:virtualMachineProfile.storageProfile.osDisk.managedDisk.storageAccountType, DiskSizeGB:virtualMachineProfile.storageProfile.osDisk.diskSizeGb, Ephemeral:virtualMachineProfile.storageProfile.osDisk.diffDiskSettings.option, Location:location}" -o json 2>/dev/null)
    
    if [ -n "$vmss_data" ]; then
        is_ephemeral=$(echo "$vmss_data" | jq -r '.Ephemeral // "null"')
        
        if [ "$is_ephemeral" == "Local" ]; then
            ephemeral_vmss+=("$vmss_data")
        else
            # Print non-ephemeral immediately
            echo "$vmss_data" | CSV_FILE="$CSV_FILE" python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    instances = data.get('Instances', 0) or 0
    disk_size = data.get('DiskSizeGB', 0) or 0
    total = instances * disk_size
    print(f\"{data.get('Name', 'N/A'):<40} {data.get('ResourceGroup', 'N/A'):<35} {instances:<10} {data.get('DiskType', 'N/A'):<15} {disk_size:<15} {total:<20} {data.get('Location', 'N/A'):<15}\")
    
    # Add to CSV
    csv_file = os.environ.get('CSV_FILE', 'output.csv')
    with open(csv_file, 'a') as f:
        f.write(f\"VMSS-Managed,{data.get('Name', 'N/A')},{data.get('ResourceGroup', 'N/A')},{instances},Linux,,{data.get('DiskType', 'N/A')},{disk_size},{total},No,{data.get('Location', 'N/A')}\n\")
except:
    pass
"
        fi
    fi
done <<< "$vmss_list"

echo ""
echo "============================================"
echo "VMSS with Ephemeral OS Disks"
echo "============================================"

# Print header for ephemeral
printf "%-40s %-35s %-10s %-15s %-15s %-20s %-15s\n" "Name" "Resource Group" "Instances" "Disk Type" "Disk Size (GB)" "Total Capacity (GB)" "Location"
printf "%-40s %-35s %-10s %-15s %-15s %-20s %-15s\n" "----" "--------------" "---------" "---------" "--------------" "-------------------" "--------"

# Print ephemeral VMSS
for vmss_data in "${ephemeral_vmss[@]}"; do
    echo "$vmss_data" | CSV_FILE="$CSV_FILE" python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    instances = data.get('Instances', 0) or 0
    disk_size = data.get('DiskSizeGB', 0) or 0
    total = instances * disk_size
    print(f\"{data.get('Name', 'N/A'):<40} {data.get('ResourceGroup', 'N/A'):<35} {instances:<10} {data.get('DiskType', 'N/A'):<15} {disk_size:<15} {total:<20} {data.get('Location', 'N/A'):<15}\")
    
    # Add to CSV
    csv_file = os.environ.get('CSV_FILE', 'output.csv')
    with open(csv_file, 'a') as f:
        f.write(f\"VMSS-Ephemeral,{data.get('Name', 'N/A')},{data.get('ResourceGroup', 'N/A')},{instances},Linux,,{data.get('DiskType', 'N/A')},{disk_size},{total},Yes,{data.get('Location', 'N/A')}\n\")
except:
    pass
"
done

echo ""
echo "============================================"
echo "Standalone VM OS Disks (Non-VMSS)"
echo "============================================"

# Get all managed OS disks with formatted output
printf "%-50s %-35s %-12s %-15s %-15s %-15s %-15s\n" "Name" "Resource Group" "OS Type" "Disk State" "Disk Type" "Disk Size (GB)" "Location"
printf "%-50s %-35s %-12s %-15s %-15s %-15s %-15s\n" "----" "--------------" "-------" "----------" "---------" "--------------" "--------"

az graph query -q "Resources | where type =~ 'microsoft.compute/disks' | where isnotempty(properties.osType) | project name, resourceGroup, osType = properties.osType, diskState = properties.diskState, skuName = sku.name, diskSizeGB = properties.diskSizeGB, location" --first 1000 -o json | CSV_FILE="$CSV_FILE" python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    disks = data.get('data', [])
    total_size = 0
    csv_file = os.environ.get('CSV_FILE', 'output.csv')
    
    for disk in disks:
        name = disk.get('name', 'N/A')
        rg = disk.get('resourceGroup', 'N/A')
        os_type = disk.get('osType', 'N/A')
        state = disk.get('diskState', 'N/A')
        sku = disk.get('skuName', 'N/A')
        size = disk.get('diskSizeGB', 0) or 0
        location = disk.get('location', 'N/A')
        total_size += size
        print(f'{name:<50} {rg:<35} {os_type:<12} {state:<15} {sku:<15} {size:<15} {location:<15}')
        
        # Add to CSV
        with open(csv_file, 'a') as f:
            f.write(f'Standalone-VM,{name},{rg},1,{os_type},{state},{sku},{size},{size},No,{location}\n')
    
    print('-' * 160)
    print('TOTAL' + ' ' * 45 + ' ' * 35 + ' ' * 12 + ' ' * 15 + ' ' * 15 + str(total_size))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
"

echo ""
echo "============================================"
echo "Summary:"
echo "- Managed Disks: created as separate Azure resources"
echo "- VMSS with Managed Disks: persistent, backed by Azure Storage"
echo "- VMSS with Ephemeral Disks: stored on local VM host, lost on deallocation"
echo "============================================"
echo ""
echo "✅ CSV file created: $CSV_FILE"
echo "   You can open this file in Excel or any spreadsheet application"
