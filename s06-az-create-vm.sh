#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "subscriptionId"
    "resourceGroupName"
    "targetDiskName"
    "newVirtualMachineName"
    "newVmSize"
    "newVirtualMachineSubnetId"
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

# Function to check if a managed disk is attached and detach it
detach_managed_disk() {
    local resource_group=$1
    local disk_name=$2

    # Check if the managed disk is attached
    attached_vm=$(az disk list --resource-group "$resource_group" --query "[?name=='$disk_name'].managedBy" --output tsv)

    if [ -n "$attached_vm" ]; then
        # Extract the VM name from the managedBy property
        vm_name=$(basename "$attached_vm")

        # Detach the managed disk
        az vm disk detach --resource-group "$resource_group" --vm-name "$vm_name" --name "$disk_name"
        echo "Managed disk '$disk_name' detached from VM '$vm_name'."
    else
        echo "Managed disk '$disk_name' is not attached to any VM."
    fi
}

####################################################################################

# Check if all required arguments have been set
check_required_arguments

# Set the context to the subscription Id where Managed Disk exists and where VM will be created
az account set --subscription $subscriptionId

# Provide the OS type
osType=linux

# Detach disk from preparation VM if needed
detach_managed_disk "$resourceGroupName" "$targetDiskName"

# Get the resource Id of the managed disk
managedDiskId=$(az disk show --name $targetDiskName --resource-group $resourceGroupName --query [id] -o tsv)

# Create VM by attaching existing managed disks as OS
az vm create \
    --name $newVirtualMachineName \
    --resource-group $resourceGroupName \
    --attach-os-disk $managedDiskId \
    --os-type $osType \
    --subnet $newVirtualMachineSubnetId \
    --public-ip-address "" \
    --size $newVmSize \
    --tag "CreatedBy=script"

# Enable boot diagnostics
az vm boot-diagnostics enable \
    --name $newVirtualMachineName \
    --resource-group $resourceGroupName
