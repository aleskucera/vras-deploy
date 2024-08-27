#!/bin/bash
set -eo pipefail  # Exit immediately if a command fails and ensure errors in pipelines are caught

# Function to print the usage information for this script
print_usage() {
    cat <<EOF
Usage: bash start_container.sh [OPTIONS]

This script starts a RoboTour Apptainer container. It performs the following steps:

  1. Validates the environment and dependencies.
  2. Checks if the necessary Apptainer image is available.
  3. Sets up the environment variables required for the container.
  4. Launches the Apptainer container with appropriate configurations.

Options:
  -h, --help    Show this help message and exit.
  --nv          Enable NVIDIA GPU support in the container.
EOF
}

# ============= START: Source the variables and utility functions =============

# Source the variables and utility functions from external scripts
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/vars.sh"
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/utils.sh"

# ============= END: Source the variables and utility functions =============

# ============= START: Helper Functions =============

# Function to get bind paths based on the hardware type (e.g., amd64, arm64, jetson)
get_mount_paths() {
    local hardware_type=$1  # The hardware type passed as an argument
    local paths
    
    # Determine the bind paths based on the hardware type
    case "$hardware_type" in 
        "amd64"|"arm64"|"jetson")
            paths="${MOUNT_PATHS["common"]}${MOUNT_PATHS[$hardware_type]}"
            ;;
        *)
            error_log "Unknown hardware type: $hardware_type"
            exit 1  # Exit if an unknown hardware type is encountered
            ;;
    esac

    echo "$paths"  # Return the determined bind paths
}

# ============= END: Helper Functions =============

# ============= START: Main =============

# Main function to handle the execution of the script
main() {
    nvidia_gpu=""          # Default is no NVIDIA GPU support
    download_image=false   # Flag for image download, currently not used

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
            print_usage  # Show usage information
            exit 0
            ;;
            --nv)
            nvidia_gpu="--nv"  # Enable NVIDIA GPU support
            shift # Move to the next argument
            ;;
            *)
            print_usage  # Show usage information if an unknown option is encountered
            handle_error "Unknown option: $1"
            shift # Move to the next argument or value
            ;;
        esac
    done

    # If there are more than one arguments left after parsing, show usage and exit with an error
    if [[ $# -gt 1 ]]; then
        print_usage
        handle_error "Unknown option: $1"
    fi

    echo
    echo "================ STARTING APPTAINER CONTAINER ================="
    echo

    # Check if Apptainer is installed, and install it if not
    if ! is_apptainer_installed; then
        error_log "Apptainer is not installed. Please install it first."
        read_input "Do you want to install ${CYAN}Apptainer${RESET} now? (y/N) " response

        # If the user agrees to install Apptainer, run the installation script
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "${SCRIPTS_DIR}/install_apptainer.sh"
        else
            exit 1  # Exit if the user chooses not to install Apptainer
        fi
    fi    
    
    # Check if already inside an Apptainer container, exit with an error if so
    if in_apptainer; then
        error_log "You are already inside an Apptainer container." && exit 1
    fi

    # Check if the specified image file exists
    if [ ! -f "$IMAGE_FILE" ]; then
        error_log "Image file ${PINK}${IMAGE_FILE}${RESET} does not exist."
        read_input "Do you want to download the image? [y/N] "

        # If the user agrees to download the image, ask for the username and download it
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read_input "Enter the username for the remote server ${PINK}${REMOTE_SERVER}${RESET}: "
            bash "${SCRIPTS_DIR}/transfer_image.sh" download -u "$REPLY"
        else
            exit 1  # Exit if the user chooses not to download the image
        fi
    fi

    # Warn the user if NVIDIA GPU support is not enabled
    if [ "$nvidia_gpu" = "" ]; then
        warn_log "You are not using NVIDIA GPU support. If you have \n\
        \ran NVIDIA GPU, you can enable it by using the ${YELLOW}--nv${RESET} option."
    fi


    export APPTAINERENV_WORKSPACE_DIR="${WORKSPACE_DIR}"

    # Log the start of the container and execute the container with the appropriate settings
    info_log "Starting Apptainer container from image ${PINK}$(basename "${IMAGE_FILE}")${RESET}."
    apptainer exec $nvidia_gpu -B "$(get_mount_paths "$HARDWARE_TYPE")" -e $IMAGE_FILE "${SCRIPTS_DIR}/init_workspace.sh"
}

# ============= END: Main =============

# Execute the main function with all passed arguments
main "$@"

