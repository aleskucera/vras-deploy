#!/bin/bash

# Function to print the usage information for this script
print_usage() {
    cat <<EOF
Usage: bash transfer_image.sh <operation> [OPTIONS]

This script transfers a RoboTour Singularity image between your local machine and the RCI server.

Operations:
  upload:   Upload the image to the RCI server.
  download: Download the image from the RCI server.

Options:
  -h, --help                 Show this help message and exit.
  -u, --username <username>  Specify the username to use when connecting to the RCI server.
EOF
}

# ============= START: Source the variables and utility functions =============

# Source the variables and utility functions from external scripts
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/vars.sh"
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/utils.sh"

# ============= END: Source the variables and utility functions =============

# Main function to handle the transfer operations
main() {
    local operation=""  # Initialize the operation variable
    
    # Ensure at least one argument (operation) is provided
    if [[ $# -lt 1 ]]; then
        print_usage
        exit 1
    fi

    # Set the operation (upload/download) and shift arguments
    operation="$1"
    shift # Remove operation from arguments

    # Parse the remaining command-line options
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
            print_usage  # Display usage information and exit
            exit 0
            ;;
            -u|--username)
            USERNAME="$2"  # Capture the username for the RCI server
            shift # Past argument
            shift # Past value
            ;;
            *)
            print_usage  # Display usage information for unknown options
            handle_error "Unknown option: $1"
            exit 1
            ;;
        esac
    done

    # Ensure the operation is either "upload" or "download"
    if [ "$operation" != "upload" ] && [ "$operation" != "download" ]; then
        print_usage
        handle_error "Invalid operation: $operation"
        exit 1
    fi

    # Ensure that user is online
    if [ ! is_online ]; then
        error_log "You do not seem to be online. Please connect to the internet and try again."
        exit 1
    fi

    # Output the operation being performed
    if [ "$operation" == "download" ]; then
        echo
        echo "============ DOWNLOADING SINGULARITY IMAGE ============="
        echo
    elif [ "$operation" == "upload" ]; then
        echo
        echo "============= UPLOADING SINGULARITY IMAGE =============="
        echo
    fi
    
    # Check SSH key existence or prompt for a password if not present
    check_ssh_key_or_prompt_password

    echo 
    info_log "Checking the status of the local and remote image files..."
    
    local_status=$(image_files_exist "local")
    case $? in
        0) info_log "Both local image and metadata files exist.";;
        2) error_log "Only image file exists. Metadata file is missing. Please resolve this before the transfer." && exit 1 ;;
        3) error_log "Only metadata file exists. Image file is missing. Please resolve this before the transfer." && exit 1 ;;
        4) if [ "$operation" == "upload" ]; then
                error_log "Local image nor metadata files exist. Cannot upload the image. Please build the image first." && exit 1
            else
                info_log "Neither local image nor metadata files exist. Downloading a new image..."
                transfer_image "download" && exit 0
            fi
            ;;
    esac
    
    remote_status=$(image_files_exist "remote")
    case $? in
        0) info_log "Both remote image and metadata files exist.";;
        2) error_log "Only remote image file exists. Remote metadata file is missing. Please resolve this before the transfer." && exit 1 ;;
        3) error_log "Only remote metadata file exists. Remote image file is missing. Please resolve this before the transfer." && exit 1 ;;
        4) if [ "$operation" == "download" ]; then
                error_log "Remote image nor metadata files exist. Cannot download the image." && exit 1
            else
                info_log "Neither remote image nor metadata files exist. Uploading a new image..."
                transfer_image "upload" && exit 0
            fi
            ;;
    esac

    echo 
    info_log "Checking the timestamps of the local and remote image files..."

    # Get the timestamps of the local and remote images
    local local_image_time=$(get_local_image_time)
    local remote_image_time=$(get_remote_image_time)

    info_log "Local image timestamp: ${local_image_time}"
    info_log "Remote image timestamp: ${remote_image_time}"

    echo
    read_input "Do you want to continue with the $operation? [y/N] "

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info_log "Aborting the $operation."
        exit 0
    fi

    # Transfer the image based on the operation (upload/download)
    transfer_image $operation   

    # Confirm successful transfer
    info_log "The image and metadata files have been successfully transferred."
}

# Execute the main function with all passed arguments
main "$@"
