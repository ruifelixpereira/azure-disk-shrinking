#!/bin/bash

# load environment variables
set -a && source .env && set +a

# Required variables
required_vars=(
    "lv_sizes"
    "pv_name"
    "vg_name"
    "partition_device"
    "partition_number"
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

# Function to calculate the new size of an existing partition based on the size of the volume group PV and resize it
resize_partition() {
    local vg_name=$1
    local partition=$2
    local partition_number=$3

    # Safety gap in sectors (4 sectors = 8192 bytes)
    # This is to ensure that the partition does not overlap with the LVM metadata area
    # and to leave some space for the filesystem overhead.
    local safety_gap=4

    # Run vgdisplay command and capture the output
    vgdisplay_output=$(vgdisplay "$vg_name" --units m)

    # Extract the VG size from the output
    vg_size=$(echo "$vgdisplay_output" | grep "VG Size" | awk '{print $3}')

    # Get the start sector of the existing partition
    start_sector=$(sfdisk -d "$partition" | grep "first-lba" | awk '{print $2}')

    # Calculate the new size in sectors (assuming 512 bytes per sector)
    new_size_sectors=$(echo "$vg_size * 1024 * 1024 / 512 + $start_sector + $safety_gap" | bc)

    # Resizing the partition
    echo "Resizing partition partition with a total of $new_size_sectors sectors"
    echo " ,$new_size_sectors" | sfdisk --no-reread --force -N $partition_number $partition
}

####################################################################################

# Check if all required arguments have been set
check_required_arguments

#
# Install packages
#

echo ""
echo "-------------------------------"
echo "Installing required packages..."
echo "-------------------------------"
echo ""

# Install LVM2 tools if needed
dnf install lvm2

# Install python 2
dnf install -y python2

# Install basic calcuator
dnf install -y bc


#
# Check the filesystem
#

echo ""
echo "----------------------"
echo "Checking filesystem..."
echo "----------------------"
echo ""

#fsck.ext4 -D -ff /dev/rl/root -y
#fsck.ext4 -D -ff /dev/rl/tmp -y
#fsck.ext4 -D -ff /dev/rl/opt -y
#fsck.ext4 -D -ff /dev/rl/tlanBiS -y
#fsck.ext4 -D -ff /dev/rl/var_lib_pgsql -y

# Get the array of logical volumes with new sizes
IFS=',' read -r -a array <<< "$lv_sizes"

for lv in "${array[@]}"; do

    # Get the name and size of LV
    IFS=':' read -r -a subarray <<< "$lv"
    lv_path="/dev/rl/${subarray[0]}"
    new_size="${subarray[1]}"

    # Check if the logical volume exists
    if [ ! -e "$lv_path" ]; then
        echo "Logical volume $lv_path does not exist. Skipping."
        continue
    fi

    # Check the filesystem
    echo "Running filesystem check on $lv_path..."
    fsck.ext4 -D -ff "$lv_path" -y

done

#
# Resize the logical volumes
#

echo ""
echo "---------------------------"
echo "Resizing logical volumes..."
echo "---------------------------"
echo ""

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

for lv in "${array[@]}"; do

    # Get the name and size of LV
    IFS=':' read -r -a subarray <<< "$lv"
    lv_path="/dev/rl/${subarray[0]}"
    new_size="${subarray[1]}"

    # Check if the logical volume exists
    if [ ! -e "$lv_path" ]; then
        echo "Logical volume $lv_path does not exist. Skipping."
        continue
    fi

    # Resize the LV
    echo "Resizing $lv_path to $new_size..."
    lvresize --resizefs -L $new_size $lv_path
    
done


#
# Resize physical volume
#

echo ""
echo "---------------------------"
echo "Resizing physical volume..."
echo "---------------------------"
echo ""

# Install python script
curl -o pvshrink https://raw.githubusercontent.com/ruifelixpereira/azure-disk-shrinking/refs/heads/main/pvshrink
chmod +x pvshrink

# Resize PV
./pvshrink -v $pv_name

#
# Resize partition
#

echo ""
echo "---------------------"
echo "Resizing partition..."
echo "---------------------"
echo ""

# Resize the partition
resize_partition "$vg_name" "$partition_device" $partition_number

echo ""
echo "---------------------"
echo "Done..."
echo "---------------------"
