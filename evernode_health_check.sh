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
    apt-get install -y nmap dnsutils curl ufw openssl
}

# Function to calculate required ports
calculate_required_ports() {
    local instance_count=$1
    user_ports=($(seq 22861 $((22861 + instance_count))))
    peer_ports=($(seq 26201 $((26201 + instance_count))))
    tcp_ports=($(seq 36525 $((36525 + instance_count * 2 - 1))))
    udp_ports=($(seq 39064 $((39064 + instance_count * 2 - 1))))
    all_ports=("${user_ports[@]}" "${peer_ports[@]}" "${tcp_ports[@]}" "80" "443")
    echo "${all_ports[@]}"
}

# Function to run nmap scan
run_nmap_scan() {
    local target=$1
    local ports=$2
    print_color "$YELLOW" "Running nmap scan on $target..."
    nmap -p"$ports" -Pn "$target"
}

# Function to verify UFW configuration
verify_ufw_configuration() {
    local required_ports=("$@")
    print_color "$YELLOW" "Verifying UFW configuration..."
    
    if ! command -v ufw &> /dev/null; then
        print_color "$RED" "UFW is not installed."
        return 1
    fi

    ufw_status=$(sudo ufw status)
    if [[ $ufw_status == *"inactive"* ]]; then
        print_color "$RED" "Warning: UFW is inactive."
        return 1
    fi

    print_color "$GREEN" "UFW is active."
    
    local missing_rules=()
    for port in "${required_ports[@]}"; do
        if ! sudo ufw status | grep -q "$port"; then
            missing_rules+=("$port")
        fi
    done

    if [ ${#missing_rules[@]} -eq 0 ]; then
        print_color "$GREEN" "All required ports are properly configured in UFW."
    else
        print_color "$YELLOW" "The following ports are not configured in UFW: ${missing_rules[*]}"
    fi
}

# Function to check SSL certificate
check_ssl_certificate() {
    local domain=$1
    print_color "$YELLOW" "Checking SSL certificate for $domain..."
    
    if ! openssl s_client -connect "${domain}:443" -servername "${domain}" </dev/null 2>/dev/null | openssl x509 -noout -text; then
        print_color "$RED" "Failed to retrieve SSL certificate information."
        return 1
    fi
}

# Function to generate comprehensive report
generate_report() {
    local domain=$1
    local lan_ip=$2
    local required_ports=("$@")
    shift 2

    print_color "$YELLOW" "Generating Comprehensive Report"
    print_color "$YELLOW" "--------------------------------"
    
    echo "Domain: $domain"
    echo "LAN IP: $lan_ip"
    echo "Required Ports: ${required_ports[*]}"
    
    echo -e "\nNmap Scan Results (Domain):"
    run_nmap_scan "$domain" "$(IFS=,; echo "${required_ports[*]}")"
    
    echo -e "\nNmap Scan Results (LAN IP):"
    run_nmap_scan "$lan_ip" "$(IFS=,; echo "${required_ports[*]}")"
    
    echo -e "\nUFW Configuration:"
    verify_ufw_configuration "${required_ports[@]}"
    
    echo -e "\nSSL Certificate Information:"
    check_ssl_certificate "$domain"
}

# Main script execution
if [ "$EUID" -ne 0 ]; then
    print_color "$RED" "Please run this script as root or with sudo."
    exit 1
fi

install_deps

read -p "Enter the domain name of your Evernode host: " domain_name
resolved_ip=$(dig +short "$domain_name")
echo "Resolved IP: $resolved_ip"

gateway_ip=$(curl -s https://ipinfo.io/ip)
echo "Gateway Public IP: $gateway_ip"

if [ "$resolved_ip" != "$gateway_ip" ]; then
    print_color "$RED" "Error: DNS public IP mismatch. Please check your DNS configuration."
fi

lan_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
echo "LAN IP: $lan_ip"

read -p "How many Evernode instances do you have? " instance_count

required_ports=($(calculate_required_ports "$instance_count"))

generate_report "$domain_name" "$lan_ip" "${required_ports[@]}"

print_color "$YELLOW" "Evernode Node Health Check Complete"
print_color "$YELLOW" "Please review the report above for any issues or misconfigurations."
