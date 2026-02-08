#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global error flag
HAS_ERRORS=0

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log errors
log_error() {
    local message=$1
    print_color "$RED" "ERROR: $message"
    HAS_ERRORS=1
}

# Function to log warnings
log_warning() {
    local message=$1
    print_color "$YELLOW" "WARNING: $message"
}

# Function to log success
log_success() {
    local message=$1
    print_color "$GREEN" "SUCCESS: $message"
}

# Function to log info
log_info() {
    local message=$1
    print_color "$BLUE" "INFO: $message"
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Function to install dependencies
install_deps() {
    print_color "$YELLOW" "Installing dependencies..."
    
    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    if ! apt-get install -y nmap dnsutils curl ufw openssl jq docker.io 2>/dev/null; then
        log_warning "Some dependencies failed to install. Continuing anyway..."
    fi
    
    log_success "Dependencies installation completed"
}

# Function to check system requirements
check_system_requirements() {
    print_color "$YELLOW" "\n=== System Requirements Check ==="
    
    # Check CPU cores (minimum 4 recommended for Evernode)
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    echo "CPU Cores: $cpu_cores"
    if [ "$cpu_cores" -ge 4 ]; then
        log_success "CPU cores meet requirements (${cpu_cores} cores, minimum 4 recommended)"
    else
        log_warning "CPU cores below recommended (${cpu_cores} cores, minimum 4 recommended)"
    fi
    
    # Check RAM (minimum 8GB recommended)
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$(echo "scale=2; $total_ram_kb / 1024 / 1024" | bc)
    available_ram_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    available_ram_gb=$(echo "scale=2; $available_ram_kb / 1024 / 1024" | bc)
    
    echo "Total RAM: ${total_ram_gb} GB"
    echo "Available RAM: ${available_ram_gb} GB"
    
    if (( $(echo "$total_ram_gb >= 8" | bc -l) )); then
        log_success "RAM meets requirements (${total_ram_gb} GB, minimum 8 GB recommended)"
    else
        log_error "RAM below minimum requirements (${total_ram_gb} GB, minimum 8 GB recommended)"
    fi
    
    if (( $(echo "$available_ram_gb < 2" | bc -l) )); then
        log_warning "Low available RAM (${available_ram_gb} GB available)"
    fi
    
    # Check disk space (minimum 50GB free recommended)
    disk_info=$(df -h / | tail -1)
    disk_total=$(echo "$disk_info" | awk '{print $2}')
    disk_used=$(echo "$disk_info" | awk '{print $3}')
    disk_avail=$(echo "$disk_info" | awk '{print $4}')
    disk_percent=$(echo "$disk_info" | awk '{print $5}')
    
    echo "Disk Space (Root): Total: $disk_total, Used: $disk_used, Available: $disk_avail ($disk_percent used)"
    
    disk_avail_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$disk_avail_gb" -ge 50 ]; then
        log_success "Disk space meets requirements (${disk_avail_gb}GB available, minimum 50GB recommended)"
    else
        log_warning "Disk space below recommended (${disk_avail_gb}GB available, minimum 50GB recommended)"
    fi
}

# Function to check system uptime
check_system_uptime() {
    print_color "$YELLOW" "\n=== System Uptime Check ==="
    
    if check_command "uptime"; then
        uptime_info=$(uptime -p 2>/dev/null || uptime)
        echo "System Uptime: $uptime_info"
        
        # Check load average
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
        echo "Load Average: $load_avg"
        
        log_success "System uptime retrieved"
    else
        log_error "Unable to retrieve system uptime"
    fi
}

# Function to check Docker status and version
check_docker_status() {
    print_color "$YELLOW" "\n=== Docker Status Check ==="
    
    if ! check_command "docker"; then
        log_error "Docker is not installed (REQUIRED for Evernode)"
        echo "Install with: apt-get update && apt-get install -y docker.io"
        return 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
    echo "Docker Version: $docker_version"
    
    if ! systemctl is-active --quiet docker; then
        log_error "Docker service is not running (CRITICAL)"
        echo "Start with: systemctl start docker && systemctl enable docker"
        return 1
    fi
    
    log_success "Docker service is running"
    
    # Check Docker containers
    running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    all_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
    stopped_containers=$((all_containers - running_containers))
    
    echo "Running containers: $running_containers / $all_containers"
    if [ $stopped_containers -gt 0 ]; then
        log_warning "$stopped_containers container(s) are stopped"
    fi
    
    # Show Evernode-related containers (sashimono)
    evernode_containers=$(docker ps -a --filter "name=sashimono" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)
    if [ -n "$evernode_containers" ]; then
        echo -e "\nEvernode (Sashimono) Containers:"
        echo "$evernode_containers" | column -t
        
        # Check if any sashimono containers are not running
        stopped_sashimono=$(docker ps -a --filter "name=sashimono" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
        if [ -n "$stopped_sashimono" ]; then
            log_error "Some Evernode containers are not running: $stopped_sashimono"
        else
            running_sashimono=$(docker ps --filter "name=sashimono" --format "{{.Names}}" 2>/dev/null | wc -l)
            if [ "$running_sashimono" -gt 0 ]; then
                log_success "All Evernode containers are running"
            fi
        fi
    else
        log_warning "No Evernode (sashimono) containers found. Has Evernode been installed?"
    fi
    
    # Check Docker disk usage
    docker_disk=$(docker system df 2>/dev/null | grep "^Images\|^Containers\|^Local Volumes")
    if [ -n "$docker_disk" ]; then
        echo -e "\nDocker Disk Usage:"
        echo "$docker_disk"
    fi
}

# Function to check network latency
check_network_latency() {
    print_color "$YELLOW" "\n=== Network Latency Check ==="
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 4 -W 2 "$host" &> /dev/null; then
            avg_latency=$(ping -c 4 "$host" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
            if [ -n "$avg_latency" ]; then
                echo "Average latency to $host: ${avg_latency}ms"
                
                # Check if latency is acceptable (< 100ms)
                if (( $(echo "$avg_latency < 100" | bc -l 2>/dev/null || echo "0") )); then
                    log_success "Latency to $host is acceptable"
                else
                    log_warning "High latency to $host (${avg_latency}ms)"
                fi
            fi
        else
            log_error "Unable to ping $host"
        fi
    done
}

# Function to check SSH configuration
check_ssh_security() {
    print_color "$YELLOW" "\n=== SSH Security Check ==="
    
    local ssh_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$ssh_config" ]; then
        log_error "SSH configuration file not found"
        return 1
    fi
    
    # Check PermitRootLogin
    root_login=$(grep -i "^PermitRootLogin" "$ssh_config" | awk '{print $2}')
    if [ "$root_login" == "no" ] || [ "$root_login" == "prohibit-password" ]; then
        log_success "Root login is properly restricted ($root_login)"
    else
        log_warning "Root login may be enabled. Consider setting 'PermitRootLogin no'"
    fi
    
    # Check PasswordAuthentication
    pass_auth=$(grep -i "^PasswordAuthentication" "$ssh_config" | awk '{print $2}')
    if [ "$pass_auth" == "no" ]; then
        log_success "Password authentication is disabled (key-based only)"
    else
        log_warning "Password authentication may be enabled. Consider using key-based auth only"
    fi
    
    # Check SSH port
    ssh_port=$(grep -i "^Port" "$ssh_config" | awk '{print $2}')
    if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
        log_success "SSH running on non-standard port: $ssh_port"
    else
        log_info "SSH running on standard port 22"
    fi
}

# Function to check open ports and potential security risks
check_open_ports_security() {
    print_color "$YELLOW" "\n=== Open Ports Security Analysis ==="
    
    if ! check_command "netstat"; then
        if ! check_command "ss"; then
            log_error "Neither netstat nor ss is available for port checking"
            return 1
        fi
        # Use ss instead of netstat
        listening_ports=$(ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -u)
    else
        listening_ports=$(netstat -tuln | grep LISTEN | awk '{print $4}' | sed 's/.*://' | sort -u)
    fi
    
    echo "Currently listening ports:"
    echo "$listening_ports"
    
    # Check for commonly vulnerable ports
    vulnerable_ports=("23" "21" "3389" "5900")
    found_vulnerable=0
    
    for port in "${vulnerable_ports[@]}"; do
        if echo "$listening_ports" | grep -q "^${port}$"; then
            log_warning "Potentially insecure service on port $port"
            found_vulnerable=1
        fi
    done
    
    if [ $found_vulnerable -eq 0 ]; then
        log_success "No obviously vulnerable ports detected"
    fi
}

# Function to check XRPL account balances
check_xrpl_balance() {
    local account=$1
    local account_name=$2
    
    if [ -z "$account" ]; then
        log_error "No account address provided for $account_name"
        return 1
    fi
    
    print_color "$YELLOW" "\nChecking balance for $account_name: $account"
    
    # Query XRPL using public API
    local api_url="https://xrplcluster.com"
    
    local response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"account_info\",
            \"params\": [{
                \"account\": \"$account\",
                \"ledger_index\": \"validated\"
            }]
        }" 2>/dev/null)
    
    if [ -z "$response" ]; then
        log_error "Failed to retrieve balance for $account_name"
        return 1
    fi
    
    # Parse XAH balance (XRP in drops, divide by 1000000)
    local xah_drops=$(echo "$response" | jq -r '.result.account_data.Balance // "error"' 2>/dev/null)
    
    if [ "$xah_drops" == "error" ] || [ "$xah_drops" == "null" ] || [ -z "$xah_drops" ]; then
        log_error "Unable to parse balance for $account_name. Account may not exist or API error occurred"
        return 1
    fi
    
    local xah_balance=$(echo "scale=2; $xah_drops / 1000000" | bc 2>/dev/null)
    echo "  XAH Balance: $xah_balance XAH"
    
    # Check if balance is above 50 XAH
    if (( $(echo "$xah_balance >= 50" | bc -l 2>/dev/null) )); then
        log_success "$account_name has sufficient XAH balance (${xah_balance} XAH)"
    else
        log_warning "$account_name has insufficient XAH balance (${xah_balance} XAH, needs >= 50 XAH)"
    fi
    
    # Check EVR balance (if applicable - EVR is a trust line)
    local evr_balance=$(echo "$response" | jq -r '.result.account_data.Balance // "0"' 2>/dev/null)
    
    # Query for trust lines to get EVR balance
    local trustlines_response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"account_lines\",
            \"params\": [{
                \"account\": \"$account\",
                \"ledger_index\": \"validated\"
            }]
        }" 2>/dev/null)
    
    # Look for EVR trustline (currency code: 4556520000000000000000000000000000000000)
    local evr_line=$(echo "$trustlines_response" | jq -r '.result.lines[] | select(.currency == "4556520000000000000000000000000000000000") | .balance' 2>/dev/null | head -1)
    
    if [ -n "$evr_line" ] && [ "$evr_line" != "null" ]; then
        echo "  EVR Balance: $evr_line EVR"
        
        if (( $(echo "$evr_line >= 50" | bc -l 2>/dev/null) )); then
            log_success "$account_name has sufficient EVR balance (${evr_line} EVR)"
        else
            log_warning "$account_name has insufficient EVR balance (${evr_line} EVR, needs >= 50 EVR)"
        fi
    else
        log_warning "No EVR trust line found for $account_name or EVR balance is 0"
    fi
}

# Function to check Evernode installation
check_evernode_installation() {
    print_color "$YELLOW" "\n=== Evernode Installation Check ==="
    
    # Check for Evernode CLI
    if check_command "evernode"; then
        evernode_version=$(evernode version 2>/dev/null || echo "Unknown")
        echo "Evernode CLI Version: $evernode_version"
        log_success "Evernode CLI is installed"
    else
        log_error "Evernode CLI is not installed"
        echo "Install from: https://github.com/EvernodeXRPL/evernode-host"
        return 1
    fi
    
    # Check Evernode configuration directory
    evernode_config_dir="$HOME/.evernode"
    if [ -d "$evernode_config_dir" ]; then
        log_success "Evernode configuration directory exists: $evernode_config_dir"
        
        # Check for important config files
        if [ -f "$evernode_config_dir/config.json" ]; then
            echo "Configuration file found: config.json"
        else
            log_warning "Configuration file not found: config.json"
        fi
    else
        log_warning "Evernode configuration directory not found: $evernode_config_dir"
    fi
    
    # Check Evernode service status
    if systemctl list-unit-files | grep -q "evernode"; then
        evernode_service=$(systemctl list-unit-files | grep evernode | awk '{print $1}' | head -1)
        if systemctl is-active --quiet "$evernode_service"; then
            log_success "Evernode service is running: $evernode_service"
        else
            log_error "Evernode service is not running: $evernode_service"
        fi
    else
        log_warning "No Evernode systemd service found"
    fi
}

# Function to check Evernode host status
check_evernode_host_status() {
    print_color "$YELLOW" "\n=== Evernode Host Status ==="
    
    if ! check_command "evernode"; then
        log_warning "Evernode CLI not available. Skipping host status check"
        return 1
    fi
    
    # Try to get host info
    host_info=$(evernode status 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$host_info" ]; then
        echo "$host_info"
        log_success "Evernode host status retrieved"
    else
        log_warning "Unable to retrieve Evernode host status. Host may not be registered"
    fi
}

# Function to check Evernode accounts
check_evernode_accounts() {
    print_color "$YELLOW" "\n=== Evernode Account Balance Check ==="
    
    # Check if jq is available for JSON parsing
    if ! check_command "jq"; then
        log_error "jq is required for account balance checking. Installing..."
        apt-get install -y jq 2>/dev/null || {
            log_error "Failed to install jq. Skipping account balance check"
            return 1
        }
    fi
    
    # Check if bc is available for calculations
    if ! check_command "bc"; then
        log_error "bc is required for balance calculations. Installing..."
        apt-get install -y bc 2>/dev/null || {
            log_error "Failed to install bc. Skipping account balance check"
            return 1
        }
    fi
    
    # Try to auto-detect accounts from Evernode config
    evernode_config="$HOME/.evernode/config.json"
    auto_host_account=""
    auto_rep_account=""
    
    if [ -f "$evernode_config" ]; then
        auto_host_account=$(jq -r '.host.address // empty' "$evernode_config" 2>/dev/null)
        auto_rep_account=$(jq -r '.reputation.address // empty' "$evernode_config" 2>/dev/null)
    fi
    
    # Prompt for host account (with auto-detected default)
    if [ -n "$auto_host_account" ]; then
        read -p "Enter your Evernode host account address [detected: $auto_host_account] (or press Enter to use detected): " host_account
        host_account=${host_account:-$auto_host_account}
    else
        read -p "Enter your Evernode host account address (or press Enter to skip): " host_account
    fi
    
    if [ -n "$host_account" ]; then
        check_xrpl_balance "$host_account" "Host Account"
    else
        log_warning "Host account check skipped (RECOMMENDED to check)"
    fi
    
    # Prompt for reputation account (with auto-detected default)
    if [ -n "$auto_rep_account" ]; then
        read -p "Enter your Evernode reputation account address [detected: $auto_rep_account] (or press Enter to use detected): " reputation_account
        reputation_account=${reputation_account:-$auto_rep_account}
    else
        read -p "Enter your Evernode reputation account address (or press Enter to skip): " reputation_account
    fi
    
    if [ -n "$reputation_account" ]; then
        check_xrpl_balance "$reputation_account" "Reputation Account"
    else
        log_warning "Reputation account check skipped (RECOMMENDED to check)"
    fi
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
    print_color "$YELLOW" "\n=== UFW Configuration Check ==="
    
    if ! check_command "ufw"; then
        log_error "UFW is not installed"
        return 1
    fi

    ufw_status=$(sudo ufw status 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Unable to check UFW status. Make sure you have sudo privileges"
        return 1
    fi
    
    if [[ $ufw_status == *"inactive"* ]]; then
        log_error "UFW is inactive. Please enable it with 'sudo ufw enable'"
        return 1
    fi

    log_success "UFW is active"
    
    # Show current UFW status
    echo -e "\nCurrent UFW Rules:"
    sudo ufw status numbered
    
    local missing_rules=()
    for port in "${required_ports[@]}"; do
        if ! sudo ufw status | grep -q "$port"; then
            missing_rules+=("$port")
        fi
    done

    if [ ${#missing_rules[@]} -eq 0 ]; then
        log_success "All required ports are properly configured in UFW"
    else
        log_warning "The following ports are not configured in UFW: ${missing_rules[*]}"
        echo "You may want to add them with: sudo ufw allow <port>"
    fi
}

# Function to check SSL certificate
check_ssl_certificate() {
    local domain=$1
    print_color "$YELLOW" "\n=== SSL Certificate Check ==="
    print_color "$YELLOW" "Checking SSL certificate for $domain..."
    
    if ! check_command "openssl"; then
        log_error "OpenSSL is not installed"
        return 1
    fi
    
    # Try to get certificate info
    cert_info=$(echo | openssl s_client -connect "${domain}:443" -servername "${domain}" 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$cert_info" ]; then
        log_error "Failed to retrieve SSL certificate information for $domain"
        return 1
    fi
    
    echo "$cert_info"
    
    # Check certificate expiration
    expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    if [ -n "$expiry_date" ]; then
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ $days_until_expiry -lt 0 ]; then
            log_error "SSL certificate has expired!"
        elif [ $days_until_expiry -lt 30 ]; then
            log_warning "SSL certificate expires in $days_until_expiry days"
        else
            log_success "SSL certificate is valid for $days_until_expiry more days"
        fi
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
main() {
    print_color "$BLUE" "====================================="
    print_color "$BLUE" "Evernode Node Doctor - Health Check"
    print_color "$BLUE" "====================================="
    echo ""
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script as root or with sudo"
        exit 1
    fi

    # Install dependencies
    install_deps || log_warning "Some dependencies may be missing"
    
    # System requirements check (CRITICAL)
    check_system_requirements
    
    # Basic system checks
    check_system_uptime
    
    # Docker check (CRITICAL for Evernode)
    check_docker_status
    
    # Evernode installation check
    check_evernode_installation
    
    # Network latency
    check_network_latency
    
    # Security checks
    check_ssh_security
    check_open_ports_security
    
    # Domain and network configuration
    print_color "$YELLOW" "\n=== Domain and Network Configuration ==="
    read -p "Enter the domain name of your Evernode host: " domain_name
    
    if [ -z "$domain_name" ]; then
        log_error "Domain name cannot be empty"
        exit 1
    fi
    
    if ! check_command "dig"; then
        log_error "dig command not found. Cannot resolve domain"
        exit 1
    fi
    
    resolved_ip=$(dig +short "$domain_name" 2>/dev/null | tail -1)
    if [ -z "$resolved_ip" ]; then
        log_error "Failed to resolve domain: $domain_name"
    else
        echo "Resolved IP: $resolved_ip"
    fi

    gateway_ip=$(curl -s https://ipinfo.io/ip 2>/dev/null)
    if [ -z "$gateway_ip" ]; then
        log_error "Failed to retrieve gateway public IP"
    else
        echo "Gateway Public IP: $gateway_ip"
    fi

    if [ -n "$resolved_ip" ] && [ -n "$gateway_ip" ]; then
        if [ "$resolved_ip" != "$gateway_ip" ]; then
            log_error "DNS public IP mismatch. DNS points to $resolved_ip but gateway is $gateway_ip"
        else
            log_success "DNS configuration is correct"
        fi
    fi

    lan_ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$lan_ip" ]; then
        log_error "Failed to determine LAN IP"
    else
        echo "LAN IP: $lan_ip"
    fi

    # Instance count and port configuration
    read -p "How many Evernode instances do you have? " instance_count
    
    if ! [[ "$instance_count" =~ ^[0-9]+$ ]] || [ "$instance_count" -lt 1 ]; then
        log_error "Invalid instance count. Must be a positive number"
        exit 1
    fi

    required_ports=($(calculate_required_ports "$instance_count"))

    # Generate comprehensive report
    generate_report "$domain_name" "$lan_ip" "${required_ports[@]}"
    
    # Check Evernode host status
    check_evernode_host_status
    
    # Check Evernode account balances (CRITICAL)
    check_evernode_accounts
    
    # Check fail2ban
    print_color "$YELLOW" "\n=== Fail2ban Status ==="
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        log_success "Fail2ban is active"
        fail2ban-client status 2>/dev/null || log_warning "Unable to get fail2ban status details"
    else
        log_warning "Fail2ban is not active or not installed"
    fi
    
    # Final summary
    print_color "$BLUE" "\n====================================="
    print_color "$BLUE" "Health Check Complete"
    print_color "$BLUE" "====================================="
    
    if [ $HAS_ERRORS -eq 1 ]; then
        print_color "$RED" "\n⚠ Errors were detected during the health check"
        print_color "$RED" "Please review the output above and address any issues"
        exit 1
    else
        print_color "$GREEN" "\n✓ All checks passed successfully!"
        print_color "$GREEN" "Your Evernode node appears to be healthy"
    fi
}

# Run main function
main
