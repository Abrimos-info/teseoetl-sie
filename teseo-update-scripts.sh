#!/bin/bash

# This script installs dependencies for teseo scripts
# Usage:
#   1. Update all submodules and their dependencies:
#      git submodule update --recursive --remote
#      git submodule foreach ./teseo-update-scripts.sh
#
#   2. Update a single submodule's dependencies:
#      sm_path=[submodule-path] ./teseo-update-scripts.sh

# Function to install dependencies based on project type
install_deps() {
    local dir=$1
    
    echo "Pulling latest changes in $dir"
    cd "$dir" && git pull
    
    if [ -f "package.json" ]; then
        echo "Installing Node.js dependencies in $dir"
        npm install
    elif [ -f "requirements.txt" ]; then
        echo "Installing Python dependencies in $dir"
        pip install -r requirements.txt
    else
        echo "No package.json or requirements.txt found in $dir"
    fi
}

# Function to check for uncommitted changes
check_uncommitted_changes() {
    local dir=$1
    cd "$dir"

    if ! git diff-index --quiet HEAD --; then
        echo "Uncommitted changes detected. Please commit or stash them before proceeding."
        echo $PWD
        exit 1
    fi
}

# Function to initialize submodules if not already initialized
initialize_submodules() {
    git submodule init
}

echo "Teseo Update Scripts $sm_path"


# If sm_path is provided, only process that directory
if [ ! -z "$sm_path" ]; then
    if [ -d "$sm_path" ]; then
        check_uncommitted_changes "$sm_path"
        install_deps "$sm_path"
    elif [ "$(realpath "../../$sm_path")" == "$PWD" ]; then
        check_uncommitted_changes $PWD
        install_deps $PWD
    else
        echo $PWD
        echo "Directory $sm_path does not exist"
        exit 1
    fi
else
    # Initialize submodules if needed
    initialize_submodules

    # Process all subdirectories in teseo_scripts
    if [ -d "teseo_scripts" ]; then
        for dir in ./teseo_scripts/*/; do
            if [ -d "$dir" ]; then
                check_uncommitted_changes "$dir"
                install_deps "$dir"
            fi
        done
    else
        echo "teseo_scripts directory not found"
        exit 1
    fi
fi
