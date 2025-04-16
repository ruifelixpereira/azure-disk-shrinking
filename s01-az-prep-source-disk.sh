#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "subscriptionId"
    "resourceGroupName"
    "originalDiskName"
    "sourceSnapshotName"
    "sourceDiskName"
    "prepVirtualMachineName"
    "prepVmSize"
    "prepVirtualMachineSubnetId"
    "prepOSDiskSnapshotName"
    "prepOSDiskName"
)

# Set the current directory to where the script lives.
cd "$(dirname "$0")"

# Function to check if all required arguments have been set
check_required_arguments() {
    # Array to store the names of the missing arguments
    local missing_arguments=()

    # Loop through the array of required argument names
    for arg_name in "${required_vars[@]}"; do
        # Check if the argument value is empty
        if [[ -z "${!arg_name}" ]]; then
            # Add the name of the missing argument to the array
            missing_arguments+=("${arg_name}")
        fi
    done

    # Check if any required argument is missing
    if [[ ${#missing_arguments[@]} -gt 0 ]]; then
        echo -e "\nError: Missing required arguments:"
        printf '  %s\n' "${missing_arguments[@]}"
        [ ! \( \( $# == 1 \) -a \( "$1" == "-c" \) \) ] && echo "  Either provide a .env file or all the arguments, but not both at the same time."
        [ ! \( $# == 22 \) ] && echo "  All arguments must be provided."
        echo ""
        exit 1
    fi
}

####################################################################################

# Check if all required arguments have been set
check_required_arguments

# Set the context to the subscription Id where Managed Disk exists and where VM will be created
az account set --subscription $subscriptionId

#resource_query=$(az disk list --resource-group "$resourceGroupName" --query "[?name=='$originalDiskName']")
#if [ "$resource_query" == "[]" ]; then
#   echo -e "\nDisk does not exist '$originalDiskName'"
#else
#   echo "Disk $originalDiskName already exists."
#fi

# Check if disk exists
ORIGINAL_DISK_ID=$(az disk show --name "$originalDiskName" --resource-group "$resourceGroupName" --query id -o tsv 2>/dev/null)
if [ -z "$ORIGINAL_DISK_ID" ]; then
    echo "Disk $originalDiskName does not exist in resource group $resourceGroupName."
    exit 1
fi

# Get original disk details
Disk=$(az disk show --ids "$ORIGINAL_DISK_ID" --query "{sku:sku.name, hyperVGeneration:hyperVGeneration, diskSizeGB:diskSizeGB}" -o json)
#HyperVGen=$(echo "$Disk" | jq -r '.hyperVGeneration')
diskSizeGB=$(echo "$Disk" | jq -r '.diskSizeGB')

# Provide the storage type for Managed Disk. Acceptable values are Standard_LRS, Premium_LRS, PremiumV2_LRS, StandardSSD_LRS, UltraSSD_LRS, Premium_ZRS, and StandardSSD_ZRS.
storageType=$(echo "$Disk" | jq -r '.sku')

# Create snapshot from the original disk
sourceSnapshotId=$(az snapshot create --name $sourceSnapshotName --resource-group $resourceGroupName --incremental false --source $originalDiskName --query [id] -o tsv)

# Create a new Managed Disks using the snapshot Id
# Note that managed disk will be created in the same location as the snapshot
# If you're creating a Premium SSD v2 or an Ultra Disk, add "--zone $zone" to the end of the command
SOURCE_DISK_ID=$(az disk create --resource-group $resourceGroupName --name $sourceDiskName --sku $storageType --size-gb $diskSizeGB --source $sourceSnapshotId --query [id] -o tsv)

# Get the OS disk snapshot Id 
snapshotId=$(az snapshot show --name $prepOSDiskSnapshotName --resource-group $resourceGroupName --query [id] -o tsv)

# Create a new Managed Disks using the snapshot Id
# Note that managed disk will be created in the same location as the snapshot
OS_DISK_ID=$(az disk create --resource-group $resourceGroupName --name $prepOSDiskName --sku "StandardSSD_LRS" --size-gb 16 --source $snapshotId --query [id] -o tsv)

# Create VM by attaching existing managed disks as OS
az vm create \
    --name $prepVirtualMachineName \
    --resource-group $resourceGroupName \
    --attach-os-disk $OS_DISK_ID \
    --attach-data-disks $SOURCE_DISK_ID \
    --os-type "Linux" \
    --subnet $prepVirtualMachineSubnetId \
    --public-ip-address "" \
    --size $prepVmSize \
    --tag "CreatedBy=script"

# Enable boot diagnostics
az vm boot-diagnostics enable \
    --name $prepVirtualMachineName \
    --resource-group $resourceGroupName
