#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "subscriptionId"
    "resourceGroupName"
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
SOURCE_DISK_ID=$(az disk show --name "$sourceDiskName" --resource-group "$resourceGroupName" --query id -o tsv 2>/dev/null)
if [ -z "$SOURCE_DISK_ID" ]; then
    echo "Disk $sourceDiskName does not exist in resource group $resourceGroupName."
    exit 1
fi

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
