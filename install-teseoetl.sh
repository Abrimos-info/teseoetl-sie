# TeseoETL 1.0 Installer for Ubuntu 24.04

set -x

# Install dependencies
apt update
apt install -y git nginx python3-certbot-nginx
#apt install -y docker-ce docker-compose-plugin  # Ubuntu 20
apt install -y docker-compose-v2  #Ubuntu 24

# Install Node.js and npm using nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR=/root/.nvm
. "$NVM_DIR/nvm.sh"
nvm install 18.20.4
nvm use 18.20.4
nvm alias default 18.20.4
export PATH="/root/.nvm/versions/node/v18.20.4/bin/:${PATH}"

docker compose -f docker-compose-nifi-tika.yml up --no-start
docker compose -f docker-compose-opensearch.yml up --no-start

# Enable docker service on restart
sudo systemctl enable docker

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "No Git repository found. Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial commit from installer"
        
    # If .gitmodules exists, re-add all submodules
    if [ -f ".gitmodules" ]; then
        echo "Re-adding submodules from .gitmodules..."
        # Extract submodule information from .gitmodules
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[submodule\ \"(.*)\" ]]; then
                submodule_name="${BASH_REMATCH[1]}"
                # Read the next lines to get path and URL
                read -r path_line
                read -r url_line
                submodule_path=$(echo "$path_line" | awk '{print $3}')
                submodule_url=$(echo "$url_line" | awk '{print $3}')
                
                echo "Adding submodule $submodule_name at $submodule_path from $submodule_url"
                
                # Check if directory exists but is not a valid git repository
                if [ -d "$submodule_path" ] && [ ! -d "$submodule_path/.git" ]; then
                    echo "Directory $submodule_path exists but is not a valid git repository. Removing it..."
                    rm -rf "$submodule_path"
                fi
                
                # Add the submodule
                git submodule add -f "$submodule_url" "$submodule_path" || echo "Failed to add submodule $submodule_name, continuing anyway"
            fi
        done < .gitmodules
    fi
fi

# Initialize submodules if .gitmodules exists
if [ -f ".gitmodules" ]; then
    echo "Initializing Git submodules..."
    
    # Initialize submodules
    git submodule init

    git submodule update --init --recursive

    
    # Clone/update submodules
    echo "Updating submodules..."
    git submodule update --recursive --remote
    
    # Run the update script on each submodule
    git submodule foreach '../../teseo-update-scripts.sh' 
fi

# Create nifi dirs
mkdir -p nifi/flowfile_repository
mkdir -p nifi/provenance_repository
mkdir -p nifi/certs
mkdir -p nifi/state

set +x
