#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "source_device"
    "target_device"
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

echo "---------------------------"
echo "Original partitions layout."
echo "---------------------------"

# Dump the original disk layout to a file
sfdisk -d /dev/${source_device} > ${source_device}.layout
cat ${source_device}.layout

# Customize layout file to remove 2 lines
sed -i '/device: /d' ${source_device}.layout
sed -i '/last-lba: /d' ${source_device}.layout

# Apply the layout to the new disk:
sfdisk /dev/${target_device} < ${source_device}.layout

echo "-----------------------"
echo "New partitions created."
echo "-----------------------"

# Check the new layout
sfdisk -d /dev/${target_device}

# Copy partitions from /dev/${source_device} to /dev/${target_device}
dd if=/dev/${source_device}1 of=/dev/${target_device}1 bs=2048k status=progress
dd if=/dev/${source_device}2 of=/dev/${target_device}2 bs=2048k status=progress
dd if=/dev/${source_device}3 of=/dev/${target_device}3 bs=4096k status=progress

echo "-------------------------------"
echo "Partitions copied successfully."
echo "-------------------------------"