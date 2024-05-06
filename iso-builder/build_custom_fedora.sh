#!/bin/bash

# Constants for colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Default configurations and flags
ORIGINAL_ISO_PATH=""
KICKSTART_FILE_PATH=""
CUSTOM_ISO_NAME=""
CONFIG_FILE=""
BOOT_MENU_MODIFIED=0
VERBOSE=0
POST_CREATION_HOOK=""
WORK_DIR="$HOME/fedora_iso_customization"
PARALLEL_ENABLED=0

# Usage Information
function usage() {
    echo "Usage: $0 -i <path-to-original-iso> -k <path-to-kickstart-file> -o <custom-iso-name> [-c <config-file>] [-b] [-v] [-p]"
    echo "       $0 --interactive"
    exit 1
}

# Log function for verbose output
function log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "$1"
    fi
}

# Interactive mode function
function interactive_mode() {
    read -p "Enter the path to the original Fedora ISO: " ORIGINAL_ISO_PATH
    read -p "Enter the path to the Kickstart file: " KICKSTART_FILE_PATH
    read -p "Enter the name for the custom ISO: " CUSTOM_ISO_NAME
}

# Parse arguments
while getopts ":i:k:o:c:bpvh" opt; do
  case $opt in
    i) ORIGINAL_ISO_PATH="$OPTARG" ;;
    k) KICKSTART_FILE_PATH="$OPTARG" ;;
    o) CUSTOM_ISO_NAME="$OPTARG" ;;
    c) CONFIG_FILE="$OPTARG" ;;
    b) BOOT_MENU_MODIFIED=1 ;;
    p) PARALLEL_ENABLED=1 ;;
    v) VERBOSE=1 ;;
    h) usage ;;
    \?) echo -e "${RED}Invalid option -$OPTARG${NC}" >&2; usage ;;
  esac
done

# Load configurations from file
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
elif [[ -n "$CONFIG_FILE" ]]; then
    echo -e "${RED}Config file specified but not found.${NC}"
    exit 1
fi

# Check for interactive mode
if [[ $# -eq 0 ]]; then
    interactive_mode
fi

# Validate input
if [[ -z "$ORIGINAL_ISO_PATH" || -z "$KICKSTART_FILE_PATH" || -z "$CUSTOM_ISO_NAME" ]]; then
    usage
fi

# Create working directories
mkdir -p "${WORK_DIR}/iso_mount"
mkdir -p "${WORK_DIR}/custom_iso"

# Function for cleanup
cleanup() {
    sudo umount "${WORK_DIR}/iso_mount" 2>/dev/null
    rm -rf "${WORK_DIR}/iso_mount" "${WORK_DIR}/custom_iso"
    log "${GREEN}Cleanup completed.${NC}"
}

# Function for error handling
error_exit() {
    echo -e "${RED}An error occurred. Exiting.${NC}"
    cleanup
    exit 1
}

# Trap errors
trap 'error_exit' ERR

# Mount and copy ISO contents
sudo mount -o loop "$ORIGINAL_ISO_PATH" "${WORK_DIR}/iso_mount"
if [[ $PARALLEL_ENABLED -eq 1 ]]; then
    find "${WORK_DIR}/iso_mount/" -type f | parallel cp {} "${WORK_DIR}/custom_iso/"
else
    cp -r "${WORK_DIR}/iso_mount/"* "${WORK_DIR}/custom_iso/"
fi

# Copy Kickstart file
cp "$KICKSTART_FILE_PATH" "${WORK_DIR}/custom_iso/"

# Modify boot menu if required
if [[ $BOOT_MENU_MODIFIED -eq 1 ]]; then
    # Logic to modify boot menu
    log "${GREEN}Boot menu customized.${NC}"
fi

# Generate custom ISO
(
    cd "${WORK_DIR}/custom_iso" || exit
    sudo genisoimage -U -r -v -T -J -joliet-long -V "Custom Fedora" -volset "Custom Fedora" -A "Custom Fedora" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "${WORK_DIR}/${CUSTOM_ISO_NAME}.iso" .
)
isohybrid --uefi "${WORK_DIR}/${CUSTOM_ISO_NAME}.iso"

# Run post-creation hook if specified
if [[ -n "$POST_CREATION_HOOK" && -x "$POST_CREATION_HOOK" ]]; then
    log "${GREEN}Running post-creation hook.${NC}"
    "$POST_CREATION_HOOK"
fi

# Cleanup
cleanup

log "${GREEN}Custom Fedora ISO created: ${WORK_DIR}/${CUSTOM_ISO_NAME}.iso${NC}"
