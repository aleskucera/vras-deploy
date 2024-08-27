#!/bin/bash
set -eo pipefail  # Exit immediately if a command exits with a non-zero status, and ensure errors in pipelines are caught

# Function to print the usage guide for the script
print_usage() {
    cat <<EOF
Usage: bash build_image.sh [OPTIONS]

This script builds an apptainer image based on a definition file located in the build directory.

Options:
  -h, --help    Show this help message and exit.
EOF
}


# ============= START: Source the variables and utility functions =============

# Source the variables and utility functions from external scripts
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/vars.sh"
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/utils.sh"

# ============= END: Source the variables and utility functions =============

# Function to create metadata file with creation time and user info
create_metadata() {
    created_at=$(date +"%Y-%m-%d %H:%M:%S")  # Get the current date and time
    created_by=$(git config --get user.name) # Get the current Git user's name

    # Write metadata to a JSON file
    echo "{
    \"created_at\": \"${created_at}\",
    \"created_by\": \"${created_by}\"
}" > "${METADATA_FILE}"
}

# Function to handle existing images: prompt for backup or deletion
remove_image_or_create_backup() {
    # Ask the user if they want to create a backup of the existing image
    read_input "This will remove the old image ${PINK}$(basename "${IMAGE_FILE}")${RESET}. Do you want to create backup? [y/N] "
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        # If the user chooses not to create a backup, delete the old image and its metadata
        sudo rm -f "${IMAGE_FILE}"
        sudo rm -f "${METADATA_FILE}"
    else
        # If the user chooses to create a backup, rename the old image and its metadata
        sudo mv "${IMAGE_FILE}"{,.bak}
        sudo mv "${METADATA_FILE}"{,.bak}
    fi
}

# Function to build the Apptainer image
build_image() {
    cd "${BUILD_DIR}" || exit 1
    if [ "${HARDWARE_TYPE}" = "jetson" ]; then
        # Set temporary and cache directories for Jetson architecture
        export APPTAINER_TMPDIR="${HOME}/.apptainer_tmp"
        export APPTAINER_CACHEDIR="${HOME}/.apptainer_cache"
        # Build the image with Nvidia GPU support, logging output to the log file
        sudo -E apptainer build --nv "${IMAGE_FILE}" "${DEFINITION_FILE}" 2>&1 | tee "${LOG_FILE}"
    else
        # Build the image with Nvidia GPU support, logging output to the log file
        sudo apptainer build --nv "${IMAGE_FILE}" "${DEFINITION_FILE}" 2>&1 | tee "${LOG_FILE}"
    fi
}

# Function to change ownership and permissions of the image and metadata files
change_owner_and_rights() {
    sudo chown "${USER}":"${USER}" "${IMAGE_FILE}"
    sudo chown "${USER}":"${USER}" "${METADATA_FILE}"
    sudo chmod 775 "${IMAGE_FILE}"
    sudo chmod 664 "${METADATA_FILE}"
}

main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
            print_usage   # Display usage information
            exit 0        # Exit after printing help
            ;;
            *)
            print_usage   # Display usage information if an unknown option is provided
            handle_error "Unknown option: $1"
            shift         # Move to the next argument
            ;;
        esac
    done
    
    echo
    echo "============= BUILDING APPTAINER IMAGE =============="
    echo

    # Change to the build directory, or exit with an error if it fails
    cd "${BUILD_PATH}" || exit 1

    # Log the start of the image build process
    info_log "Building image ${PINK}$(basename "${IMAGE_FILE}")${RESET} based on ${PINK}$(basename "${DEFINITION_FILE}")${RESET}."

    # If the image file already exists, prompt the user to remove or back it up
    if [ -e "${IMAGE_FILE}" ]; then
        remove_image_or_create_backup
    fi

    # Build the image, create metadata, and set appropriate ownership and permissions
    build_image
    create_metadata
    change_owner_and_rights
}

main "$@"
