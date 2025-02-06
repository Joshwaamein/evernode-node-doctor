#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Get domain name
read -p "Enter the domain name of your Evernode host: " domain_name
resolved_ip=$(dig +short "$domain_name")
echo "Resolved IP: $resolved_ip"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_color "$RED" "Please run this script as root or with sudo."
    exit 1
fi

# Function to install dependencies
install_deps() {
    print_color "$YELLOW" "Installing dependencies..."
    apt-get update
    apt-get install -y nmap dnsutils curl ufw
}

# Function to check system resources
check_system_resources() {
    print_color "$YELLOW" "Checking system resources..."
    cpu_cores=$(nproc)
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    available_ram=$(free -m | awk '/^Mem:/{print $7}')
    disk_space=$(df -h / | awk 'NR==2 {print $4}')
  
    echo "CPU cores: $cpu_cores"
    echo "Total RAM: $total_ram MB"
    echo "Available RAM: $available_ram MB"
    echo "Available disk space: $disk_space"
  
    # Check if resources meet minimum requirements
    if [ $cpu_cores -lt 2 ]; then
        print_color "$RED" "Warning: CPU cores are less than recommended minimum (2 cores)"
    fi
    if [ $total_ram -lt 4096 ]; then
        print_color "$RED" "Warning: Total RAM is less than recommended minimum (4096 MB)"
    fi
    if [ $available_ram -lt 2048 ]; then
        print_color "$RED" "Warning: Available RAM is less than recommended minimum (2048 MB)"
    fi
    if [[ ${disk_space%G} -lt 20 ]]; then
        print_color "$RED" "Warning: Available disk space is less than recommended minimum (20G)"
    fi
}

# Install dependencies
install_deps

# Get public IP of local gateway
gateway_ip=$(curl -s https://ipinfo.io/ip)
echo "Gateway Public IP: $gateway_ip"

if [ "$resolved_ip" != "$gateway_ip" ]; then
    print_color "$RED" "Error: DNS public IP mismatch. Please check your DNS configuration."
fi

# Get quantity of Evernode instances
read -p "How many Evernode instances do you have? " instance_count

# Calculate ports to check
user_ports=($(seq 22861 $((22861 + instance_count))))
peer_ports=($(seq 26201 $((26201 + instance_count))))
tcp_ports=($(seq 36525 $((36525 + instance_count * 2 - 1))))
udp_ports=($(seq 39064 $((39064 + instance_count * 2 - 1))))

all_ports=("${user_ports[@]}" "${peer_ports[@]}" "${tcp_ports[@]}" "${udp_ports[@]}" "80")

# Check ports of gateway
print_color "$YELLOW" "Checking gateway ports..."
nmap -p$(IFS=,; echo "${all_ports[*]}") $domain_name

# Check ports of host
print_color "$YELLOW" "Checking localhost ports..."
nmap -p$(IFS=,; echo "${all_ports[*]}") localhost

# Print UFW configuration
print_color "$YELLOW" "UFW Configuration:"
ufw_status=$(ufw status verbose)
echo "$ufw_status"
if [[ $ufw_status == *"inactive"* ]]; then
    print_color "$RED" "Warning: UFW is inactive. Consider enabling it for better security."
fi

# Check if fail2ban is installed
if command -v fail2ban-client &> /dev/null; then
    print_color "$GREEN" "fail2ban is installed."
    fail2ban-client status
else
    print_color "$RED" "Warning: fail2ban is not installed. Consider installing it for better security."
fi

# Check system resources
check_system_resources
