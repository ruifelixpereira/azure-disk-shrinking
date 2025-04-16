#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "subscriptionId"
    "resourceGroupName"
    "targetDiskSizeGb"
    "targetDiskName"
    "prepVirtualMachineName"
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

#
# Reboot preparation VM
#
az vm restart -g "$resourceGroupName" -n "$prepVirtualMachineName"

#
# Create new target empty disk
#

# Get location from RG
location=$(az group show --name "$resourceGroupName" --query location -o tsv)

# Fixed values
DiskType="StandardSSD_LRS"
HyperVGen="V2"

# Create empty disk
TARGET_DISK_ID=$(az disk create --resource-group "$resourceGroupName" --name "$targetDiskName" --size-gb "$targetDiskSizeGb" --location "$location" --sku "$DiskType" --hyper-v-generation "$HyperVGen" --query [id] -o tsv)

#
# Attach empty disk to VM
#
az vm disk attach --vm-name "$prepVirtualMachineName" --resource-group "$resourceGroupName" --disks "$TARGET_DISK_ID"
