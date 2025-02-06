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

# Function to check ports
check_ports() {
    local target=$1
    local ports=$2
    local open_ports=()
    local filtered_ports=()
    local closed_ports=()

    print_color "$YELLOW" "Checking ports on $target..."
    
    while IFS= read -r line; do
        if [[ $line =~ ([0-9]+)/tcp[[:space:]]+(open|closed|filtered) ]]; then
            port="${BASH_REMATCH[1]}"
            state="${BASH_REMATCH[2]}"
            if [ "$state" == "open" ]; then
                open_ports+=("$port")
            elif [ "$state" == "filtered" ]; then
                filtered_ports+=("$port")
            else
                closed_ports+=("$port")
            fi
        fi
    done < <(nmap -p"$ports" -Pn "$target" | grep "/tcp")

    if [ ${#open_ports[@]} -eq 0 ] && [ ${#filtered_ports[@]} -eq 0 ]; then
        print_color "$RED" "No required ports are open or filtered on $target."
    elif [ $((${#open_ports[@]} + ${#filtered_ports[@]})) -eq $(echo $ports | tr ',' '\n' | wc -l) ]; then
        print_color "$GREEN" "All required ports are either open or filtered on $target."
    else
        print_color "$YELLOW" "Port status on $target:"
        [ ${#open_ports[@]} -gt 0 ] && echo "Open ports: ${open_ports[*]}"
        [ ${#filtered_ports[@]} -gt 0 ] && echo "Filtered ports: ${filtered_ports[*]}"
        [ ${#closed_ports[@]} -gt 0 ] && echo "Closed ports: ${closed_ports[*]}"
    fi

    if [ ${#filtered_ports[@]} -gt 0 ]; then
        print_color "$YELLOW" "Note: Filtered ports may be due to firewall rules or network configuration."
        print_color "$YELLOW" "These ports might still be functional for Evernode."
    fi
}

# Function to check UFW configuration
check_ufw_config() {
    print_color "$YELLOW" "Checking UFW configuration..."
    
    if ! command -v ufw &> /dev/null; then
        print_color "$RED" "UFW is not installed. Please install UFW for better security."
        return
    fi

    ufw_status=$(sudo ufw status)
    if [[ $ufw_status == *"inactive"* ]]; then
        print_color "$RED" "Warning: UFW is inactive. Consider enabling it for better security."
        return
    fi

    print_color "$GREEN" "UFW is active."
    
    local missing_rules=()
    for port in "${all_ports[@]}"; do
        if ! sudo ufw status | grep -q "$port"; then
            missing_rules+=("$port")
        fi
    done

    if [ ${#missing_rules[@]} -eq 0 ]; then
        print_color "$GREEN" "All required ports are properly configured in UFW."
    else
        print_color "$YELLOW" "The following ports are not configured in UFW: ${missing_rules[*]}"
        print_color "$YELLOW" "Consider adding rules for these ports using:"
        for port in "${missing_rules[@]}"; do
            echo "sudo ufw allow $port/tcp"
        done
    fi
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_color "$RED" "Please run this script as root or with sudo."
    exit 1
fi

# Install dependencies
install_deps

# Get domain name
read -p "Enter the domain name of your Evernode host: " domain_name
resolved_ip=$(dig +short "$domain_name")
echo "Resolved IP: $resolved_ip"

# Get public IP of local gateway
gateway_ip=$(curl -s https://ipinfo.io/ip)
echo "Gateway Public IP: $gateway_ip"

if [ "$resolved_ip" != "$gateway_ip" ]; then
    print_color "$RED" "Error: DNS public IP mismatch. Please check your DNS configuration."
fi

# Get LAN IP of the host
lan_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
echo "LAN IP: $lan_ip"

# Get quantity of Evernode instances
read -p "How many Evernode instances do you have? " instance_count

# Calculate ports to check
user_ports=($(seq 22861 $((22861 + instance_count))))
peer_ports=($(seq 26201 $((26201 + instance_count))))
tcp_ports=($(seq 36525 $((36525 + instance_count * 2 - 1))))
udp_ports=($(seq 39064 $((39064 + instance_count * 2 - 1))))

all_ports=("${user_ports[@]}" "${peer_ports[@]}" "${tcp_ports[@]}" "80")

# Check ports of gateway
check_ports "$domain_name" "$(IFS=,; echo "${all_ports[*]}")"

# Check ports of host (using LAN IP)
check_ports "$lan_ip" "$(IFS=,; echo "${all_ports[*]}")"

# Check UFW configuration
check_ufw_config

# Check if fail2ban is installed
if command -v fail2ban-client &> /dev/null; then
    print_color "$GREEN" "fail2ban is installed."
    fail2ban-client status
else
    print_color "$RED" "Warning: fail2ban is not installed. Consider installing it for better security."
fi

# Check system resources
check_system_resources

print_color "$YELLOW" "Port Status Summary:"
print_color "$YELLOW" "--------------------"
print_color "$YELLOW" "Ensure all required ports are open or filtered on both your gateway and LAN IP."
print_color "$YELLOW" "Filtered ports may still be functional for Evernode, but consider investigating further."
print_color "$YELLOW" "If any ports are closed, configure your firewall to open them."
print_color "$YELLOW" "For the gateway, you may need to set up port forwarding on your router."
print_color "$YELLOW" "For the LAN IP, check your UFW configuration and other local firewall settings."
