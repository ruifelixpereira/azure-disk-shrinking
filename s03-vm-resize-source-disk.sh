#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "lv_sizes"
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

#
# Install packages
#

# Install LVM2 tools if needed
dnf install lvm2

# Install python 2
dnf install -y python2

#
# Check the filesystem
#

#fsck.ext4 -D -ff /dev/rl/root -y
#fsck.ext4 -D -ff /dev/rl/tmp -y
#fsck.ext4 -D -ff /dev/rl/opt -y
#fsck.ext4 -D -ff /dev/rl/tlanBiS -y
#fsck.ext4 -D -ff /dev/rl/var_lib_pgsql -y

for lv in "${!lv_sizes[@]}"; do
    lv_path="/dev/rl/$lv"
    new_size="${lv_sizes[$lv]}"

    echo "Processing $lv_path to resize to $new_size..."

    # Check if the logical volume exists
    if [ ! -e "$lv_path" ]; then
        echo "Logical volume $lv_path does not exist. Skipping."
        continue
    fi

    # Check the filesystem
    echo "Running filesystem check on $lv_path..."
    echo "fsck.ext4 -D -ff \"$lv_path\" -y"
done

#
# Resize the logical volumes
#

# 20G -> 10G
#lvresize --resizefs -L 10G /dev/rl/root
#resize2fs /dev/rl/root 10GB
#lvreduce -L10G /dev/rl/root

# 2G -> 1G
#lvresize --resizefs -L 1G /dev/rl/tmp
#resize2fs /dev/rl/tmp 1GB
#lvreduce -L1G /dev/rl/tmp

# 10G -> 8G 
#lvresize --resizefs -L 8G /dev/rl/opt
#resize2fs /dev/rl/opt 8GB
#lvreduce -L8G /dev/rl/opt

# 15G -> 12G
#lvresize --resizefs -L 12G /dev/rl/tlanBiS
#resize2fs /dev/rl/tlanBiS 12GB
#lvreduce -L12G /dev/rl/tlanbis

# 15G -> 13G
#lvresize --resizefs -L 13G /dev/rl/var_lib_pgsql
#resize2fs /dev/rl/var_lib_pgsql 13GB
#lvreduce -L13G /dev/rl/var_lib_pgsql

