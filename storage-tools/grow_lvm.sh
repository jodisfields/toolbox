#!/bin/bash

# Script to extend the fedora-root logical volume

# Function to check available space in the volume group
check_vg_space() {
    echo "Checking available space in the volume group..."
    vgs
}

# Function to extend the logical volume
extend_lv() {
    local lv_path="/dev/fedora/root"
    local size=$1  # Size to increase in GB

    # Validate input
    if [[ -z "$size" ]]; then
        echo "Error: Size to increase must be provided."
        exit 1
    fi

    echo "Extending the logical volume $lv_path by $size GB..."
    lvextend -L +${size}G $lv_path
}

# Function to resize the filesystem
resize_fs() {
    local lv_path="/dev/fedora/root"

    # Detect the filesystem type and resize accordingly
    local fs_type=$(lsblk -f | grep "$(basename $lv_path)" | awk '{print $2}')
    case $fs_type in
        ext4)
            resize2fs $lv_path
            ;;
        xfs)
            xfs_growfs $lv_path
            ;;
        *)
            echo "Error: Unsupported filesystem type: $fs_type"
            exit 1
            ;;
    esac
}

# Main script logic
main() {
    local size=$1

    # Check available space in volume group
    check_vg_space

    # Extend the logical volume
    extend_lv $size

    # Resize the filesystem
    resize_fs

    # Verify changes
    echo "Changes successfully applied. Current Disk Space Usage:"
    df -h
}

# Script execution starts here
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <size_to_increase_in_GB>"
    exit 1
fi

main $1
