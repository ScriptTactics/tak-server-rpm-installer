#!/bin/bash
# Function to display a progress bar
function show_progress_bar() {
  local duration=$1
  local elapsed=0
  local progress=0

  while [[ $elapsed -lt $duration ]]; do
    # Calculate the progress percentage
    progress=$((elapsed * 100 / duration))

    # Draw the progress bar
    bar="["
    for ((i=0; i<50; i++)); do
      if [[ $((i * 2)) -lt $progress ]]; then
        bar+="="
      else
        bar+=" "
      fi
    done
    bar+="]"

    # Print the progress bar with a carriage return
    echo -ne "\r$bar $progress%"

    # Sleep for 1 second
    sleep 1

    # Increment the elapsed time
    elapsed=$((elapsed + 1))
  done

  # Print newline after the progress bar
  echo ""
}
# Error handling
set -e

# Print script introduction
echo "====================================="
echo ""
echo "This script will install all dependencies for TAK Server, install TAK Server, setup certificates, and configure basic firewall rules."
echo ""
echo "====================================="
read -p "Press any key to begin ..."

# Update and upgrade system
echo "Updating and upgrading system..."
sudo yum update -y
sudo yum upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo yum install -y epel-release
sudo yum install -y java-11-openjdk-devel
sudo yum install -y patch
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Install TAK Server
echo "====================================="
echo "Installing TAK Server..."
echo "====================================="

echo "Enter the name of your file (Press Enter to use the default: takserver-4.9-RELEASE23.noarch.rpm): "
read -r FILE_NAME
FILE_NAME="${FILE_NAME:-takserver-4.9-RELEASE23.noarch.rpm}"
sudo yum install -y "$FILE_NAME"

# Install DB
echo "====================================="
echo "Installing DB"
echo "====================================="

sudo /opt/tak/db-utils/takserver-setup-db.sh

# Restart daemon
echo "====================================="
echo "Restarting daemon"
echo "====================================="

sudo systemctl daemon-reload
sleep 5

# Enable TAK Server
echo "====================================="
echo "Enabling TAK Server"
echo "====================================="
sudo systemctl enable takserver
sleep 5

# Set up Certificate Authority
echo "====================================="
echo "Setting up Certificate Authority"
echo "====================================="

# Prompt for CA variables
echo "Enter your CA variables:"
while [[ -z $STATE || -z $CITY || -z $ORGANIZATION || -z $ORGANIZATIONAL_UNIT ]]; do
  read -p "STATE: " STATE
  read -p "CITY: " CITY
  read -p "ORGANIZATION: " ORGANIZATION
  read -p "ORGANIZATIONAL_UNIT: " ORGANIZATIONAL_UNIT
done
cd /opt/tak/certs
echo "Generating CA..."
sudo -E -u tak env STATE="$STATE" CITY="$CITY" ORGANIZATION="$ORGANIZATION" ORGANIZATIONAL_UNIT="$ORGANIZATIONAL_UNIT" ./makeRootCa.sh

echo "Enter the number of certificates you want to generate: (default: 3 server takserver, client user, client admin)"
read -r cert_count
cert_count="${cert_count:-3}"


# Validate if the certificate count is entered
if [[ -z $cert_count || ! $cert_count =~ ^[0-9]+$ ]]; then
  echo "Invalid certificate count. Exiting..."
  exit 1
fi

# Loop through the specified number of iterations
for ((i = 1; i <= cert_count; i++)); do
  echo "Certificate $i"
  
  # Prompt user to enter certificate type and name
  echo "Enter certificate type: "
  read -r cert_type

  echo "Enter certificate name: "
  read -r cert_name

  # Validate if certificate type and name are entered
  if [[ -z $cert_type || -z $cert_name ]]; then
    echo "Incomplete certificate details. Skipping..."
    continue
  fi

  # Generate the certificate
  sudo -E -u tak env STATE="$STATE" CITY="$CITY" ORGANIZATION="$ORGANIZATION" ORGANIZATIONAL_UNIT="$ORGANIZATIONAL_UNIT" ./makeCert.sh "$cert_type" "$cert_name"
done


echo "Restarting TAK Server... this will take 60 seconds please wait"
sudo systemctl restart takserver
# Sleep for 60 seconds with a progress bar
show_progress_bar 60 
echo "Authorizing the admin cert. ..."
sudo -E -u tak java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem


echo "====================================="
echo "Creating firewall rules"
echo "====================================="

sudo firewall-cmd --permanent --zone=public --add-port=8089/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8443/tcp
sudo firewall-cmd --reload

echo "====================================="
echo "Installation completed successfully!"
echo "====================================="
# Get the active network interface
network_interface=$(ip -o -4 route show to default | awk '{print $5}')

# Check if a network interface is found
if [[ -z $network_interface ]]; then
  echo "No active network interface found."
  exit 1
fi

# Get the IP address
ip_address=$(ip -4 addr show "$network_interface" | awk '/inet / {print $2}' | cut -d '/' -f 1)

# Check if an IP address is found
if [[ -z $ip_address ]]; then
  echo "No IP address found for network interface $network_interface."
  exit 1
fi

echo "====================================="
echo "Copy the admin.p12 file located here: /opt/tak/certs/files/admin.p12"
echo "then import it into your browser"
echo "                                 "
echo "Navigate to the ip below to finish the setup"
echo "https://$ip_address:8443/setup"
echo "====================================="
