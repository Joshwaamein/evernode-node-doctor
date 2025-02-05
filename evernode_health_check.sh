#!/bin/bash

# Print waring
echo "This script should be ran on ubuntu hosts only. Run this script with sudo or as root. Script starts in 10s..."
sleep 10


# Function to check system resources
check_system_resources() {
    echo "Checking system resources..."

    # CPU cores
    cpu_cores=$(nproc)
    echo "CPU cores: $cpu_cores"

    # RAM
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    available_ram=$(free -m | awk '/^Mem:/{print $7}')
    echo "Total RAM: $total_ram MB"
    echo "Available RAM: $available_ram MB"

    # Disk space
    disk_space=$(df -h / | awk 'NR==2 {print $4}')
    echo "Available disk space: $disk_space"

    # Check if resources meet minimum requirements
    if [ $cpu_cores -lt 2 ]; then
        echo "Warning: CPU cores are less than recommended minimum (2 cores)"
    fi
    if [ $total_ram -lt 4096 ]; then
        echo "Warning: Total RAM is less than recommended minimum (4096 MB)"
    fi
    if [ $available_ram -lt 2048 ]; then
        echo "Warning: Available RAM is less than recommended minimum (2048 MB)"
    fi
    if [[ ${disk_space%G} -lt 20 ]]; then
        echo "Warning: Available disk space is less than recommended minimum (20G)"
    fi
}

# Get domain name
read -p "Enter the domain name of your Evernode host: " domain_name
resolved_ip=$(dig +short $domain_name)
echo "Resolved IP: $resolved_ip"

# Get public IP of local gateway
gateway_ip=$(curl -s https://ipinfo.io/ip)
echo "Gateway Public IP: $gateway_ip"

if [ "$resolved_ip" != "$gateway_ip" ]; then
    echo "Error: DNS public IP mismatch. Please check your DNS configuration."
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
echo "Checking gateway ports..."
nmap -p$(IFS=,; echo "${all_ports[*]}") $domain_name

# Check ports of host
echo "Checking localhost ports..."
nmap -p$(IFS=,; echo "${all_ports[*]}") localhost

# Print UFW configuration
echo "UFW Configuration:"
sudo ufw status verbose

# Check if fail2ban is installed
if command -v fail2ban-client &> /dev/null; then
    echo "fail2ban is installed."
    sudo fail2ban-client status
else
    echo "fail2ban is not installed."
fi

# Check system resources
check_system_resources
