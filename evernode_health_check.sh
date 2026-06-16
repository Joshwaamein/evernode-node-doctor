#!/bin/bash
#
# Evernode Node Doctor - health check for Evernode hosts on Xahau.
# Safe to run interactively or from cron. See --help for options.

# Fail on unset variables and on any command in a pipeline failing.
# We deliberately do NOT use 'set -e': this script runs many checks
# that are allowed to fail individually without aborting the whole run.
set -uo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global mode flags
CRON_MODE=0
NO_COLOR=0
SKIP_ACCOUNTS=0
SKIP_LOGS=0
VERBOSE=0
JSON_MODE=0

# EVR token issuer on Xahau mainnet (protocol constant, public).
EVR_ISSUER="rEvernodee8dJLaFsujS6q1EiXvZYmHXr8"

# Recommended best-practice balances (operator buffer, NOT the protocol
# minimum; the protocol minimum is the Xahau base+owner reserve).
RECOMMENDED_XAH=50
RECOMMENDED_EVR=50

# Public Xahau JSON-RPC endpoint, used only as a last-resort fallback
# when the node's own configured rippledServer cannot be reached.
PUBLIC_XAHAU_RPC="https://xahau.network"

# Global error flag and tracking arrays
HAS_ERRORS=0
declare -a SUCCESS_MESSAGES=()
declare -a WARNING_MESSAGES=()
declare -a ERROR_MESSAGES=()

# Parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cron|--silent)
                CRON_MODE=1
                shift
                ;;
            --no-color)
                NO_COLOR=1
                shift
                ;;
            --skip-accounts)
                SKIP_ACCOUNTS=1
                shift
                ;;
            --skip-logs)
                SKIP_LOGS=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --json)
                JSON_MODE=1
                NO_COLOR=1
                CRON_MODE=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # If NO_COLOR is set, disable color codes
    if [ $NO_COLOR -eq 1 ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

# Show help message
show_help() {
    cat << EOF
Evernode Node Doctor - Health Check Script

Usage: $0 [OPTIONS]

Options:
  --cron, --silent    Run in non-interactive mode (no prompts, auto-detect all values)
  --no-color          Disable color output (useful for log files)
  --skip-accounts     Skip XRPL account balance checks
  --skip-logs         Skip Evernode log analysis (saves ~1-2 minutes)
  --verbose           Show detailed debugging information
  --json              Output a machine-readable JSON summary (implies
                      --cron and --no-color). For monitoring pipelines.
  --help, -h          Show this help message

Examples:
  # Interactive mode (default)
  sudo $0

  # Cron mode for automated monitoring
  sudo $0 --cron

  # Cron mode with output to log file
  sudo $0 --cron --no-color >> /var/log/evernode-health.log

  # Skip log analysis for faster execution
  sudo $0 --skip-logs

  # Skip both accounts and logs for fastest execution
  sudo $0 --cron --skip-accounts --skip-logs

EOF
}

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
    ERROR_MESSAGES+=("$message")
    HAS_ERRORS=1
}

# Function to log warnings
log_warning() {
    local message=$1
    print_color "$YELLOW" "WARNING: $message"
    WARNING_MESSAGES+=("$message")
}

# Function to log success
log_success() {
    local message=$1
    print_color "$GREEN" "SUCCESS: $message"
    SUCCESS_MESSAGES+=("$message")
}

# Function to log info
log_info() {
    local message=$1
    print_color "$BLUE" "INFO: $message"
}

# Function to print summary report
print_summary_report() {
    print_color "$BLUE" "\n=========================================="
    print_color "$BLUE" "           SUMMARY REPORT"
    print_color "$BLUE" "=========================================="
    
    # Success messages
    if [ ${#SUCCESS_MESSAGES[@]} -gt 0 ]; then
        print_color "$GREEN" "\n✓ SUCCESSES (${#SUCCESS_MESSAGES[@]}):"
        print_color "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for msg in "${SUCCESS_MESSAGES[@]}"; do
            echo "  ✓ $msg"
        done
    fi
    
    # Warning messages
    if [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
        print_color "$YELLOW" "\n⚠ WARNINGS (${#WARNING_MESSAGES[@]}):"
        print_color "$YELLOW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for msg in "${WARNING_MESSAGES[@]}"; do
            echo "  ⚠ $msg"
        done
    fi
    
    # Error messages
    if [ ${#ERROR_MESSAGES[@]} -gt 0 ]; then
        print_color "$RED" "\n✗ ERRORS (${#ERROR_MESSAGES[@]}):"
        print_color "$RED" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for msg in "${ERROR_MESSAGES[@]}"; do
            echo "  ✗ $msg"
        done
    fi
    
    print_color "$BLUE" "\n=========================================="
}

# Emit a machine-readable JSON summary (for monitoring pipelines).
# Uses jq to build valid JSON so message contents are safely escaped.
print_json_report() {
    local status="ok"
    if [ "$HAS_ERRORS" -eq 1 ]; then
        status="error"
    elif [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
        status="warning"
    fi

    # Build JSON arrays from the message arrays. printf '%s\0' is null
    # safe; jq -Rs splits on newlines. Empty arrays handled gracefully.
    local successes warnings errors
    successes=$(printf '%s\n' "${SUCCESS_MESSAGES[@]:-}" | jq -Rs 'split("\n") | map(select(length > 0))')
    warnings=$(printf '%s\n' "${WARNING_MESSAGES[@]:-}" | jq -Rs 'split("\n") | map(select(length > 0))')
    errors=$(printf '%s\n' "${ERROR_MESSAGES[@]:-}" | jq -Rs 'split("\n") | map(select(length > 0))')

    jq -n \
        --arg status "$status" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg host "$(hostname 2>/dev/null || echo unknown)" \
        --argjson successes "$successes" \
        --argjson warnings "$warnings" \
        --argjson errors "$errors" \
        '{
            status: $status,
            timestamp: $ts,
            host: $host,
            counts: {
                success: ($successes | length),
                warning: ($warnings | length),
                error: ($errors | length)
            },
            successes: $successes,
            warnings: $warnings,
            errors: $errors
        }'
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Function to install dependencies (only the missing ones; never in cron/json mode)
install_deps() {
    # Map: command -> apt package providing it.
    local -A pkg_for=(
        [nmap]=nmap [dig]=dnsutils [curl]=curl [ufw]=ufw
        [openssl]=openssl [jq]=jq [docker]=docker.io [bc]=bc
        [netstat]=net-tools
    )

    local missing=()
    local cmd
    for cmd in "${!pkg_for[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("${pkg_for[$cmd]}")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        log_info "All required tools already present; skipping dependency install"
        return 0
    fi

    # In cron/json mode, never mutate the system or grab the apt lock.
    # Just report what is missing and continue with degraded checks.
    if [ $CRON_MODE -eq 1 ]; then
        log_warning "Missing tools in non-interactive mode (not installing): ${missing[*]}"
        return 0
    fi

    print_color "$YELLOW" "Installing missing dependencies: ${missing[*]}"

    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # De-duplicate the package list before installing.
    local uniq_pkgs
    mapfile -t uniq_pkgs < <(printf '%s\n' "${missing[@]}" | sort -u)
    if ! apt-get install -y "${uniq_pkgs[@]}" 2>/dev/null; then
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
    
    # Show Evernode-related containers (sashimono or sashi-)
    evernode_containers=$(docker ps -a --filter "name=sashi" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)
    if [ -n "$evernode_containers" ]; then
        container_count=$(echo "$evernode_containers" | wc -l)
        echo -e "\nEvernode (Sashimono) Containers Found: $container_count"
        echo "$evernode_containers" | column -t
        
        # Check if any sashimono containers are not running
        stopped_sashimono=$(docker ps -a --filter "name=sashi" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
        if [ -n "$stopped_sashimono" ]; then
            log_error "Some Evernode containers are not running: $stopped_sashimono"
        else
            running_sashimono=$(docker ps --filter "name=sashi" --format "{{.Names}}" 2>/dev/null | wc -l)
            if [ "$running_sashimono" -gt 0 ]; then
                log_success "All $running_sashimono Evernode container(s) are running"
            fi
        fi
    else
        # If we found Evernode CLI installed, containers might be managed differently
        if check_command "evernode" &>/dev/null; then
            log_info "No Docker containers with 'sashi' prefix found"
            echo "Note: Evernode containers may be managed through the Evernode CLI"
        else
            log_warning "No Evernode (sashimono) containers found. Has Evernode been installed?"
        fi
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

# Function to check XRPL/Xahau account balances.
#   $1 = account address
#   $2 = human-readable account name
#   $3 = JSON-RPC endpoint to query (https://...). Optional; falls back
#        to the public Xahau RPC if empty.
check_xrpl_balance() {
    local account=$1
    local account_name=$2
    local api_url=${3:-$PUBLIC_XAHAU_RPC}

    if [ -z "$account" ]; then
        log_error "No account address provided for $account_name"
        return 1
    fi

    # Basic sanity check: Xahau/XRPL classic addresses start with 'r'.
    if [[ ! "$account" =~ ^r[1-9A-HJ-NP-Za-km-z]{24,34}$ ]]; then
        log_warning "$account_name address looks malformed: $account"
    fi

    print_color "$YELLOW" "\nChecking balance for $account_name: $account"
    [ $VERBOSE -eq 1 ] && echo "  Using endpoint: $api_url"

    local response
    response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 --max-time 15 \
        -d "{
            \"method\": \"account_info\",
            \"params\": [{
                \"account\": \"$account\",
                \"ledger_index\": \"validated\"
            }]
        }" 2>/dev/null)

    # Fall back to the public Xahau RPC if the configured endpoint failed
    # and we were not already using it.
    if [ -z "$response" ] && [ "$api_url" != "$PUBLIC_XAHAU_RPC" ]; then
        log_warning "Configured endpoint did not respond, retrying via public Xahau RPC"
        api_url=$PUBLIC_XAHAU_RPC
        response=$(curl -s -X POST "$api_url" \
            -H "Content-Type: application/json" \
            --connect-timeout 10 --max-time 15 \
            -d "{
                \"method\": \"account_info\",
                \"params\": [{
                    \"account\": \"$account\",
                    \"ledger_index\": \"validated\"
                }]
            }" 2>/dev/null)
    fi

    if [ -z "$response" ]; then
        log_error "Failed to retrieve balance for $account_name (no response)"
        return 1
    fi

    # Surface an explicit ledger error (e.g. actNotFound) rather than a
    # vague parse failure.
    local rpc_error
    rpc_error=$(echo "$response" | jq -r '.result.error // empty' 2>/dev/null)
    if [ -n "$rpc_error" ]; then
        log_error "$account_name lookup returned '$rpc_error' (account may be unfunded or not yet activated)"
        return 1
    fi

    # XAH balance is in drops (1 XAH = 1,000,000 drops).
    local xah_drops
    xah_drops=$(echo "$response" | jq -r '.result.account_data.Balance // empty' 2>/dev/null)

    if [ -z "$xah_drops" ]; then
        log_error "Unable to parse XAH balance for $account_name"
        return 1
    fi

    local xah_balance owner_count
    xah_balance=$(echo "scale=6; $xah_drops / 1000000" | bc 2>/dev/null)
    owner_count=$(echo "$response" | jq -r '.result.account_data.OwnerCount // 0' 2>/dev/null)
    echo "  XAH Balance: $xah_balance XAH (OwnerCount: $owner_count)"

    # NOTE: the protocol minimum is the Xahau base reserve plus
    # per-owned-object increments, not a flat number. The threshold
    # below is a recommended operator buffer on top of that reserve.
    if (( $(echo "$xah_balance >= $RECOMMENDED_XAH" | bc -l 2>/dev/null || echo 0) )); then
        log_success "$account_name has a healthy XAH buffer (${xah_balance} XAH, >= ${RECOMMENDED_XAH} recommended)"
    else
        log_warning "$account_name XAH below the recommended buffer (${xah_balance} XAH, ${RECOMMENDED_XAH} recommended). This is guidance, not the protocol reserve minimum"
    fi

    # EVR is an issued trustline asset on Xahau. Read it from account_lines.
    local trustlines_response
    trustlines_response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 --max-time 15 \
        -d "{
            \"method\": \"account_lines\",
            \"params\": [{
                \"account\": \"$account\",
                \"ledger_index\": \"validated\"
            }]
        }" 2>/dev/null)

    # Match the EVR currency from the canonical Evernode issuer. The
    # balance can be reported as a negative string depending on which
    # side of the trustline issued it; normalise to an absolute value.
    local evr_line
    evr_line=$(echo "$trustlines_response" | \
        jq -r --arg iss "$EVR_ISSUER" \
        '.result.lines[]? | select(.currency == "EVR" and .account == $iss) | .balance' \
        2>/dev/null | head -1)

    if [ -n "$evr_line" ] && [ "$evr_line" != "null" ]; then
        # Strip a leading minus for the threshold comparison only.
        local evr_abs=${evr_line#-}
        echo "  EVR Balance: $evr_line EVR"

        if (( $(echo "$evr_abs >= $RECOMMENDED_EVR" | bc -l 2>/dev/null || echo 0) )); then
            log_success "$account_name has a healthy EVR buffer (${evr_line} EVR, >= ${RECOMMENDED_EVR} recommended)"
        else
            log_warning "$account_name EVR below the recommended buffer (${evr_line} EVR, ${RECOMMENDED_EVR} recommended)"
        fi
    else
        log_warning "No EVR trust line found for $account_name (issuer ${EVR_ISSUER}), or EVR balance is 0"
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
    
    # Check Sashimono configuration directory (primary Evernode config location)
    if [ -d "/etc/sashimono" ]; then
        log_success "Evernode configuration directory found: /etc/sashimono"
        
        # Check for important config files
        if [ -f "/etc/sashimono/mb-xrpl/mb-xrpl.cfg" ]; then
            log_success "Host configuration file found: mb-xrpl.cfg"
        else
            log_warning "Host configuration file not found: mb-xrpl.cfg"
        fi
        
        if [ -f "/etc/sashimono/reputationd/reputationd.cfg" ]; then
            log_success "Reputation configuration file found: reputationd.cfg"
        else
            log_warning "Reputation configuration file not found: reputationd.cfg"
        fi
    else
        log_warning "Evernode configuration directory not found: /etc/sashimono"
        
        # Check alternative locations as fallback
        evernode_config_found=0
        possible_config_dirs=("$HOME/.evernode" "/home/sashimono/.evernode" "/root/.evernode")
        
        for config_dir in "${possible_config_dirs[@]}"; do
            if [ -d "$config_dir" ]; then
                log_success "Alternative Evernode configuration found: $config_dir"
                evernode_config_found=1
                break
            fi
        done
        
        if [ $evernode_config_found -eq 0 ]; then
            log_error "No Evernode configuration found. Has Evernode been installed?"
        fi
    fi
    
    # Check Evernode service status
    if systemctl list-unit-files | grep -q "evernode\|sashimono"; then
        evernode_service=$(systemctl list-unit-files | grep "evernode\|sashimono" | awk '{print $1}' | head -1)
        if systemctl is-active --quiet "$evernode_service" 2>/dev/null; then
            log_success "Evernode/Sashimono service is running: $evernode_service"
        else
            log_warning "Evernode/Sashimono service may not be running: $evernode_service"
        fi
    else
        log_info "No Evernode systemd service found (may be managed differently)"
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

# Evaluate a Xahau server_state and log the appropriate result.
# A node that is "full", "proposing", or "validating" is synced and
# healthy (a validator legitimately reports proposing/validating). Only
# the pre-sync states warrant an error.
evaluate_server_state() {
    local state=$1
    case "$state" in
        full|proposing|validating)
            log_success "Xahau node is synced and healthy (server_state: $state)"
            ;;
        connected|syncing|tracking)
            log_error "Xahau node not fully synced (server_state: $state). Must reach full/proposing/validating before accepting tenants"
            ;;
        *)
            log_warning "Xahau node reported an unexpected server_state: $state"
            ;;
    esac
}

# Function to check Xahau WSS connection
check_xahau_wss_connection() {
    print_color "$YELLOW" "\n=== Xahau WSS Connection Health Check ==="
    
    # Extract WSS endpoint from config
    local wss_endpoint=""
    if [ -f "/etc/sashimono/mb-xrpl/mb-xrpl.cfg" ]; then
        wss_endpoint=$(jq -r '.xrpl.rippledServer // empty' /etc/sashimono/mb-xrpl/mb-xrpl.cfg 2>/dev/null)
    fi
    
    if [ -z "$wss_endpoint" ]; then
        log_warning "Xahau WSS endpoint not found in config, skipping WSS health check"
        return 0
    fi
    
    echo "Configured Xahau WSS Endpoint: $wss_endpoint"
    
    # Method 1: Try websocat (preferred - safe, no npm conflicts)
    if check_command "websocat"; then
        echo "Testing WebSocket connection with websocat..."
        wss_response=$(echo '{"command":"server_info"}' | timeout 10 websocat -n1 "$wss_endpoint" 2>&1)
        
        if [ $? -eq 0 ] && echo "$wss_response" | jq -e '.result' &>/dev/null; then
            log_success "WSS connection to Xahau node is healthy"
            
            # Parse server info
            build_version=$(echo "$wss_response" | jq -r '.result.info.build_version // "unknown"' 2>/dev/null)
            complete_ledgers=$(echo "$wss_response" | jq -r '.result.info.complete_ledgers // "unknown"' 2>/dev/null)
            server_state=$(echo "$wss_response" | jq -r '.result.info.server_state // "unknown"' 2>/dev/null)
            
            echo "  Xahau Version: $build_version"
            echo "  Ledger Range: $complete_ledgers"
            echo "  Server State: $server_state"
            
            evaluate_server_state "$server_state"
            return 0
        else
            log_warning "WebSocket test failed, trying HTTPS API fallback..."
        fi
    else
        log_info "websocat not installed, trying HTTPS API fallback..."
        echo "Tip: Install websocat for better WSS testing: apt-get install websocat"
    fi
    
    # Method 2: Additional check with API version 1
    log_info "Testing server_info with API version 1..."
    
    # Convert wss:// to https:// for API testing
    https_endpoint="${wss_endpoint//wss:/https:}"
    
    # Check with api_version: 1 parameter
    api_v1_response=$(curl -s -X POST "$https_endpoint" \
        -H "Content-Type: application/json" \
        -d '{"method":"server_info","params":[{"api_version":1}]}' \
        --connect-timeout 10 --max-time 15 2>&1)
    
    if [ $? -eq 0 ] && echo "$api_v1_response" | jq -e '.result' &>/dev/null; then
        log_success "Server info check with API version 1 successful"
        
        server_state_v1=$(echo "$api_v1_response" | jq -r '.result.info.server_state // "unknown"' 2>/dev/null)
        echo "  Server State (API v1): $server_state_v1"
        
        evaluate_server_state "$server_state_v1"
        
        build_version_v1=$(echo "$api_v1_response" | jq -r '.result.info.build_version // "unknown"' 2>/dev/null)
        complete_ledgers_v1=$(echo "$api_v1_response" | jq -r '.result.info.complete_ledgers // "unknown"' 2>/dev/null)
        
        echo "  Xahau Version: $build_version_v1"
        echo "  Ledger Range: $complete_ledgers_v1"
        return 0
    else
        log_warning "API version 1 check failed, trying standard API fallback..."
    fi
    
    # Method 3: Fallback to HTTPS API (if WSS and API v1 fail or websocat unavailable)
    log_info "Testing with HTTPS API fallback..."
    
    api_response=$(curl -s -X POST "$https_endpoint" \
        -H "Content-Type: application/json" \
        -d '{"method":"server_info","params":[{}]}' \
        --connect-timeout 10 --max-time 15 2>&1)
    
    if [ $? -eq 0 ] && echo "$api_response" | jq -e '.result' &>/dev/null; then
        log_success "HTTPS API connection to Xahau node is healthy"
        
        build_version=$(echo "$api_response" | jq -r '.result.info.build_version // "unknown"' 2>/dev/null)
        complete_ledgers=$(echo "$api_response" | jq -r '.result.info.complete_ledgers // "unknown"' 2>/dev/null)
        server_state=$(echo "$api_response" | jq -r '.result.info.server_state // "unknown"' 2>/dev/null)
        
        echo "  Xahau Version: $build_version"
        echo "  Ledger Range: $complete_ledgers"
        echo "  Server State: $server_state"
        
        evaluate_server_state "$server_state"
        return 0
    else
        log_error "Failed to connect to Xahau endpoint: $wss_endpoint"
        echo "This may indicate network issues or Xahau node problems"
        return 1
    fi
}

# Function to check Evernode accounts
check_evernode_accounts() {
    # Skip account checks if --skip-accounts flag is set
    if [ $SKIP_ACCOUNTS -eq 1 ]; then
        log_info "Skipping account balance checks (--skip-accounts flag set)"
        return 0
    fi
    
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
    
    # Derive the JSON-RPC endpoint from the node's own configured
    # rippledServer (wss://...  ->  https://...). check_xrpl_balance
    # falls back to the public Xahau RPC if this is empty or unreachable.
    local rpc_endpoint=""
    if [ -f "/etc/sashimono/mb-xrpl/mb-xrpl.cfg" ]; then
        local cfg_wss
        cfg_wss=$(jq -r '.xrpl.rippledServer // empty' /etc/sashimono/mb-xrpl/mb-xrpl.cfg 2>/dev/null)
        if [ -n "$cfg_wss" ]; then
            rpc_endpoint="${cfg_wss//wss:/https:}"
        fi
    fi

    # Try to auto-detect accounts from multiple possible config locations
    evernode_configs=(
        "$HOME/.evernode/config.json"
        "/home/sashimono/.evernode/config.json"
        "/root/.evernode/config.json"
        "/etc/sashimono/mb-xrpl/mb-xrpl.cfg"
        "/etc/sashimono/reputationd/reputationd.cfg"
    )
    
    auto_host_account=""
    auto_rep_account=""
    
    # Try to extract from Sashimono config files (JSON format)
    if [ -f "/etc/sashimono/mb-xrpl/mb-xrpl.cfg" ]; then
        auto_host_account=$(jq -r '.xrpl.address // empty' /etc/sashimono/mb-xrpl/mb-xrpl.cfg 2>/dev/null)
    fi
    
    if [ -f "/etc/sashimono/reputationd/reputationd.cfg" ]; then
        auto_rep_account=$(jq -r '.xrpl.address // empty' /etc/sashimono/reputationd/reputationd.cfg 2>/dev/null)
    fi
    
    # Try JSON configs if not found in cfg files
    if [ -z "$auto_host_account" ] || [ -z "$auto_rep_account" ]; then
        for config_file in "${evernode_configs[@]}"; do
            if [ -f "$config_file" ] && [[ "$config_file" == *.json ]]; then
                if [ -z "$auto_host_account" ]; then
                    auto_host_account=$(jq -r '.host.address // empty' "$config_file" 2>/dev/null)
                fi
                if [ -z "$auto_rep_account" ]; then
                    auto_rep_account=$(jq -r '.reputation.address // empty' "$config_file" 2>/dev/null)
                fi
                [ -n "$auto_host_account" ] && [ -n "$auto_rep_account" ] && break
            fi
        done
    fi
    
    # In CRON_MODE, use auto-detected accounts only
    if [ $CRON_MODE -eq 1 ]; then
        if [ -n "$auto_host_account" ]; then
            echo "Using auto-detected host account: $auto_host_account"
            check_xrpl_balance "$auto_host_account" "Host Account" "$rpc_endpoint"
        else
            log_warning "Host account not auto-detected in cron mode, skipping host account check"
        fi
        
        if [ -n "$auto_rep_account" ]; then
            echo "Using auto-detected reputation account: $auto_rep_account"
            check_xrpl_balance "$auto_rep_account" "Reputation Account" "$rpc_endpoint"
        else
            log_warning "Reputation account not auto-detected in cron mode, skipping reputation account check"
        fi
    else
        # Interactive mode: Prompt for host account (with auto-detected default)
        if [ -n "$auto_host_account" ]; then
            echo "Auto-detected host account: $auto_host_account"
            read -p "Press Enter to check this account, or enter a different address: " host_account
            host_account=${host_account:-$auto_host_account}
        else
            read -p "Enter your Evernode host account address (or press Enter to skip): " host_account
        fi
        
        if [ -n "$host_account" ]; then
            check_xrpl_balance "$host_account" "Host Account" "$rpc_endpoint"
        else
            log_warning "Host account check skipped (RECOMMENDED to check)"
        fi
        
        # Prompt for reputation account (with auto-detected default)
        if [ -n "$auto_rep_account" ]; then
            echo "Auto-detected reputation account: $auto_rep_account"
            read -p "Press Enter to check this account, or enter a different address: " reputation_account
            reputation_account=${reputation_account:-$auto_rep_account}
        else
            read -p "Enter your Evernode reputation account address (or press Enter to skip): " reputation_account
        fi
        
        if [ -n "$reputation_account" ]; then
            check_xrpl_balance "$reputation_account" "Reputation Account" "$rpc_endpoint"
        else
            log_warning "Reputation account check skipped (RECOMMENDED to check)"
        fi
    fi
}

# Function to check Evernode logs for errors
check_evernode_logs() {
    # Skip log analysis if --skip-logs flag is set
    if [ $SKIP_LOGS -eq 1 ]; then
        log_info "Skipping Evernode log analysis (--skip-logs flag set)"
        return 0
    fi
    
    print_color "$YELLOW" "\n=== Evernode Log Analysis ==="
    
    # Check if evernode CLI is available
    if ! check_command "evernode"; then
        log_warning "Evernode CLI not available. Skipping log analysis"
        return 1
    fi
    
    print_color "$BLUE" "Generating Evernode logs (this takes ~1-2 minutes, please wait)..."
    
    # Generate log and capture output
    log_output=$(evernode log 2>&1)
    
    # Extract log filename from output
    log_file=$(echo "$log_output" | grep -oP '/tmp/.*\.log' | head -1)
    
    # Check if log file was created
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        log_warning "Could not generate Evernode log file"
        echo "Evernode log command output:"
        echo "$log_output"
        return 1
    fi
    
    echo "Log file generated: $log_file"
    print_color "$BLUE" "Analyzing logs for errors and failures..."
    
    # Search for error patterns (case-insensitive)
    # Filter out common false positives like "0 errors" or "no error"
    errors=$(grep -iE "(error|fail|exception|critical|fatal)" "$log_file" | \
             grep -viE "(0 errors|no error|successfully|success)" | \
             head -20)
    
    # Display results
    if [ -n "$errors" ]; then
        error_count=$(echo "$errors" | wc -l)
        log_warning "Found $error_count issue(s) in Evernode logs (showing first 20):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_color "$RED" "$errors"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Full log available at: $log_file"
        echo "To view full log: cat $log_file"
    else
        log_success "No errors found in Evernode logs"
        echo "Log file: $log_file"
    fi
}

# Evernode port base offsets (shared by calculate_required_ports and
# get_port_purpose so they never drift apart).
EVR_USER_PORT_BASE=22861   # 1 per instance: tenant WebSocket
EVR_PEER_PORT_BASE=26201   # 1 per instance: Sashimono peer-to-peer
EVR_TCP_PORT_BASE=36525    # 2 per instance: tenant instance TCP
EVR_UDP_PORT_BASE=39064    # 2 per instance: tenant instance UDP

# Function to get port purpose/description (range-based, instance-count agnostic)
get_port_purpose() {
    local port=$1
    case "$port" in
        80)  echo "HTTP: Let's Encrypt validation, HTTP-to-HTTPS redirect"; return ;;
        443) echo "HTTPS: SSL/TLS termination (reverse proxy)"; return ;;
    esac

    if [ "$port" -ge "$EVR_USER_PORT_BASE" ] && [ "$port" -lt "$EVR_PEER_PORT_BASE" ]; then
        echo "Evernode User Port: WebSocket connections from tenants"
    elif [ "$port" -ge "$EVR_PEER_PORT_BASE" ] && [ "$port" -lt "$EVR_TCP_PORT_BASE" ]; then
        echo "Evernode Peer Port: Sashimono peer-to-peer communication"
    elif [ "$port" -ge "$EVR_TCP_PORT_BASE" ] && [ "$port" -lt "$EVR_UDP_PORT_BASE" ]; then
        echo "Evernode TCP Port: Tenant instance TCP communication"
    elif [ "$port" -ge "$EVR_UDP_PORT_BASE" ] && [ "$port" -lt $((EVR_UDP_PORT_BASE + 1000)) ]; then
        echo "Evernode UDP Port: Tenant instance UDP communication"
    else
        echo "Unknown port"
    fi
}

# Function to analyze port usage (firewall vs actual listeners)
analyze_port_usage() {
    local required_ports=("$@")
    
    print_color "$YELLOW" "\n=== Port Usage Analysis ==="
    echo "Analyzing which ports are open in firewall vs actually listening..."
    
    # Get currently listening ports
    if ! check_command "netstat"; then
        if ! check_command "ss"; then
            log_error "Neither netstat nor ss is available for port checking"
            return 1
        fi
        listening_ports=$(ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -u)
    else
        listening_ports=$(netstat -tuln | grep LISTEN | awk '{print $4}' | sed 's/.*://' | sort -u)
    fi
    
    # Get UFW allowed ports
    if check_command "ufw"; then
        ufw_status=$(sudo ufw status 2>/dev/null)
        if [ $? -eq 0 ] && [[ ! $ufw_status == *"inactive"* ]]; then
            echo -e "\nPort Status Analysis:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf "%-8s %-12s %-12s %-50s\n" "Port" "Firewall" "Listening" "Purpose"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            local security_issues=0
            
            for port in "${required_ports[@]}"; do
                # Check if port is allowed in UFW
                local firewall_status="DENY"
                if echo "$ufw_status" | grep -q "$port"; then
                    firewall_status="ALLOW"
                fi
                
                # Check if port is actually listening
                local listening_status="NO"
                local listening_process=""
                if echo "$listening_ports" | grep -q "^${port}$"; then
                    listening_status="YES"
                    # Try to get the process name
                    if check_command "netstat"; then
                        listening_process=$(sudo netstat -tulnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | cut -d'/' -f2 | head -1)
                    elif check_command "ss"; then
                        listening_process=$(sudo ss -tulnp 2>/dev/null | grep ":${port} " | grep -oP 'users:\(\(".*?"\)' | sed 's/users:(("//' | sed 's/".*//' | head -1)
                    fi
                fi
                
                # Get port purpose
                local purpose=$(get_port_purpose "$port")
                
                # Determine status color and message
                local status_msg=""
                if [ "$firewall_status" == "ALLOW" ] && [ "$listening_status" == "NO" ]; then
                    status_msg="⚠ SECURITY WARNING: Port open in firewall but nothing listening"
                    security_issues=$((security_issues + 1))
                    print_color "$YELLOW" "$(printf '%-8s %-12s %-12s %s' "$port" "$firewall_status" "$listening_status" "$purpose")"
                    echo "  $status_msg"
                elif [ "$firewall_status" == "ALLOW" ] && [ "$listening_status" == "YES" ]; then
                    if [ -n "$listening_process" ]; then
                        print_color "$GREEN" "$(printf '%-8s %-12s %-12s %s (%s)' "$port" "$firewall_status" "$listening_status" "$purpose" "$listening_process")"
                    else
                        print_color "$GREEN" "$(printf '%-8s %-12s %-12s %s' "$port" "$firewall_status" "$listening_status" "$purpose")"
                    fi
                elif [ "$firewall_status" == "DENY" ] && [ "$listening_status" == "YES" ]; then
                    status_msg="⚠ Service running but blocked by firewall"
                    print_color "$YELLOW" "$(printf '%-8s %-12s %-12s %s' "$port" "$firewall_status" "$listening_status" "$purpose")"
                    echo "  $status_msg"
                else
                    # Port not in firewall and not listening - normal
                    printf '%-8s %-12s %-12s %s\n' "$port" "$firewall_status" "$listening_status" "$purpose"
                fi
            done
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Summary
            if [ $security_issues -gt 0 ]; then
                log_warning "$security_issues port(s) are open in firewall but not in use"
                echo ""
                echo "NOTE: For Evernode ports (22861+, 26201+, 36525+, 39064+), this is EXPECTED BEHAVIOR."
                echo "      These ports are pre-configured and will be used when instances are leased to tenants."
                echo "      Services bind to these ports dynamically when needed."
                echo ""
                echo "For ports 80/443 (HTTP/HTTPS):"
                echo "  - If you use a reverse proxy (nginx/caddy), ensure it's running"
                echo "  - If you don't need them, close with: sudo ufw delete allow <port>"
            else
                log_success "All open ports have services listening"
            fi
        fi
    fi
}

# Function to calculate required ports.
# User and peer ports: 1 per instance. TCP and UDP: 2 per instance.
calculate_required_ports() {
    local instance_count=$1
    user_ports=($(seq "$EVR_USER_PORT_BASE" $((EVR_USER_PORT_BASE + instance_count - 1))))
    peer_ports=($(seq "$EVR_PEER_PORT_BASE" $((EVR_PEER_PORT_BASE + instance_count - 1))))
    tcp_ports=($(seq "$EVR_TCP_PORT_BASE" $((EVR_TCP_PORT_BASE + instance_count * 2 - 1))))
    udp_ports=($(seq "$EVR_UDP_PORT_BASE" $((EVR_UDP_PORT_BASE + instance_count * 2 - 1))))
    all_ports=("${user_ports[@]}" "${peer_ports[@]}" "${tcp_ports[@]}" "${udp_ports[@]}" "80" "443")
    echo "${all_ports[@]}"
}

# Function to run nmap scan
run_nmap_scan() {
    local target=$1
    local ports=$2
    print_color "$YELLOW" "Running nmap scan on $target..."
    
    if [ -z "$ports" ]; then
        log_error "No ports provided for nmap scan"
        return 1
    fi
    
    # Run nmap with proper error handling
    if ! nmap -p"$ports" -Pn "$target" 2>&1; then
        log_warning "Nmap scan failed for $target"
        return 1
    fi
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
        log_warning "OpenSSL is not installed. Skipping SSL check"
        return 1
    fi
    
    # Check if port 443 is listening first
    local port_443_listening=0
    if command -v netstat &>/dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":443 "; then
            port_443_listening=1
        fi
    elif command -v ss &>/dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":443 "; then
            port_443_listening=1
        fi
    fi
    
    # First, check HTTPS accessibility
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "https://${domain}" --connect-timeout 5 --max-time 10 2>/dev/null)
    
    if [ -n "$http_code" ] && [[ "$http_code" =~ ^[23] ]]; then
        log_success "Domain is accessible via HTTPS (HTTP $http_code)"
        
        # Try to get certificate info through the domain (works with reverse proxy)
        cert_info=$(echo | timeout 10 openssl s_client -connect "${domain}:443" -servername "${domain}" 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$cert_info" ]; then
            echo -e "\nSSL Certificate Details:"
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
            
            # Check certificate issuer
            issuer=$(echo "$cert_info" | grep "issuer" | cut -d= -f2-)
            if [[ "$issuer" == *"Let's Encrypt"* ]]; then
                log_success "SSL certificate from Let's Encrypt (auto-renewal recommended)"
            else
                echo "Certificate issuer: $issuer"
            fi
            
            log_success "SSL certificate verified successfully"
        else
            log_warning "HTTPS is accessible but unable to retrieve certificate details"
            echo "Note: This can happen with some reverse proxy configurations"
            log_info "SSL is working through your reverse proxy (nginx)"
        fi
    else
        # HTTP code 000 or connection failed
        if [ "$port_443_listening" -eq 0 ]; then
            log_info "No web service detected on port 443 (HTTPS)"
            echo "Note: This is expected if you don't use a reverse proxy (nginx/caddy)."
            echo "      Evernode itself doesn't require HTTPS - tenant access is via dedicated ports."
            echo "      Only set up HTTPS if you want a web interface or Let's Encrypt certificates."
        else
            log_warning "Port 443 is listening but domain is not accessible (HTTP code: ${http_code:-N/A})"
            echo "Possible causes: Firewall blocking, DNS issues, or reverse proxy misconfiguration"
            echo "Verify SSL externally: curl -I https://$domain"
        fi
    fi
}

# Function to generate comprehensive report
generate_report() {
    local domain=$1
    local lan_ip=$2
    shift 2
    local required_ports=("$@")

    print_color "$YELLOW" "\n=== Comprehensive Port and Configuration Report ==="
    
    echo "Domain: $domain"
    echo "LAN IP: $lan_ip"
    echo "Required Ports: ${required_ports[*]}"
    
    # Analyze port usage (firewall vs actual listeners) - NEW FEATURE
    if [ ${#required_ports[@]} -gt 0 ]; then
        analyze_port_usage "${required_ports[@]}"
    fi
    
    # Only run nmap if we have ports to scan
    if [ ${#required_ports[@]} -gt 0 ]; then
        echo -e "\nNmap Scan Results (Domain):"
        ports_csv=$(IFS=,; echo "${required_ports[*]}")
        run_nmap_scan "$domain" "$ports_csv"
        
        echo -e "\nNmap Scan Results (LAN IP):"
        run_nmap_scan "$lan_ip" "$ports_csv"
    else
        log_warning "No ports to scan"
    fi
    
    echo -e "\nUFW Configuration:"
    verify_ufw_configuration "${required_ports[@]}"
    
    echo -e "\nSSL Certificate Information:"
    check_ssl_certificate "$domain"
}

# Main script execution
main() {
    # Parse command-line arguments first
    parse_arguments "$@"
    
    # Display ASCII art banner (suppressed in JSON mode for clean output)
    if [ $JSON_MODE -eq 0 ]; then
    echo ""
    print_color "$YELLOW" "
  ███████╗██╗   ██╗███████╗██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗
  ██╔════╝██║   ██║██╔════╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝
  █████╗  ██║   ██║█████╗  ██████╔╝██╔██╗ ██║██║   ██║██║  ██║█████╗  
  ██╔══╝  ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║╚██╗██║██║   ██║██║  ██║██╔══╝  
  ███████╗ ╚████╔╝ ███████╗██║  ██║██║ ╚████║╚██████╔╝██████╔╝███████╗
  ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝"
    print_color "$BLUE" "
         ███╗   ██╗ ██████╗ ██████╗ ███████╗
         ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
         ██╔██╗ ██║██║   ██║██║  ██║█████╗  
         ██║╚██╗██║██║   ██║██║  ██║██╔══╝  
         ██║ ╚████║╚██████╔╝██████╔╝███████╗
         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝"
    print_color "$GREEN" "
    ██████╗  ██████╗  ██████╗████████╗ ██████╗ ██████╗ 
    ██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
    ██║  ██║██║   ██║██║        ██║   ██║   ██║██████╔╝
    ██║  ██║██║   ██║██║        ██║   ██║   ██║██╔══██╗
    ██████╔╝╚██████╔╝╚██████╗   ██║   ╚██████╔╝██║  ██║
    ╚═════╝  ╚═════╝  ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
"
    
    print_color "$BLUE" "======================================"
    print_color "$BLUE" "       Health Check v3.0"
    if [ $CRON_MODE -eq 1 ]; then
        print_color "$YELLOW" "          [CRON MODE]"
    fi
    print_color "$YELLOW" "====================================="
    echo ""
    fi
    
    # Show available options (only in interactive mode)
    if [ $CRON_MODE -eq 0 ]; then
        print_color "$BLUE" "Available Options:"
        echo "  --cron, --silent    Non-interactive mode (auto-detect everything)"
        echo "  --no-color          Disable colors (for log files)"
        echo "  --skip-accounts     Skip account balance checks"
        echo "  --skip-logs         Skip log analysis (saves 1-2 minutes)"
        echo "  --help, -h          Show full help"
        echo ""
        print_color "$BLUE" "Quick Examples:"
        echo "  sudo $0 --skip-logs                    (skip intensive log check)"
        echo "  sudo $0 --cron --no-color >> log.txt   (automated monitoring)"
        echo ""
    fi
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script as root or with sudo"
        exit 1
    fi
    
    # Show log analysis notice (only in interactive mode, not in cron)
    if [ $CRON_MODE -eq 0 ] && [ $SKIP_LOGS -eq 0 ]; then
        print_color "$YELLOW" "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ℹ️  NOTE: This script will analyze Evernode logs at the end.
  
  Log generation is intensive and takes ~1-2 minutes.
  
  To skip log analysis, press Ctrl+C now and restart with:
  sudo ./evernode_health_check.sh --skip-logs
  
  Starting in 5 seconds...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
        sleep 5
        echo ""
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
    
    # Try to auto-detect domain from Evernode config
    auto_domain=""
    if [ -f "/etc/sashimono/reputationd/reputationd.cfg" ]; then
        auto_domain=$(jq -r '.contractInstance.domain // empty' /etc/sashimono/reputationd/reputationd.cfg 2>/dev/null)
    fi
    
    # In CRON_MODE, use auto-detected domain or skip
    if [ $CRON_MODE -eq 1 ]; then
        if [ -n "$auto_domain" ]; then
            domain_name="$auto_domain"
            echo "Using auto-detected domain: $domain_name"
        else
            log_warning "Domain not auto-detected in cron mode, skipping domain checks"
            domain_name=""
        fi
    else
        # Interactive mode: Prompt with auto-detected domain as default
        if [ -n "$auto_domain" ]; then
            echo "Auto-detected domain: $auto_domain"
            read -p "Press Enter to use this domain, or enter a different one: " domain_name
            domain_name=${domain_name:-$auto_domain}
        else
            read -p "Enter the domain name of your Evernode host: " domain_name
        fi
        
        if [ -z "$domain_name" ]; then
            log_error "Domain name cannot be empty"
            exit 1
        fi
    fi
    
    # Skip domain checks if no domain in cron mode
    if [ -z "$domain_name" ]; then
        log_info "Skipping domain-based checks"
        gateway_ip=""
        resolved_ip=""
        lan_ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
        if [ -z "$lan_ip" ]; then
            log_error "Failed to determine LAN IP"
        else
            echo "LAN IP: $lan_ip"
        fi
        instance_count=1
        required_ports=()
    else
    
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
        print_color "$YELLOW" "\n=== Instance Count Detection ==="
        
        # Try to auto-detect instance count from running containers
        auto_instance_count=0
        if check_command "docker" &>/dev/null; then
            auto_instance_count=$(docker ps --filter "name=sashi" --format "{{.Names}}" 2>/dev/null | wc -l)
        fi
        
        # Alternative: try to parse from evernode status
        if [ "$auto_instance_count" -eq 0 ] && check_command "evernode" &>/dev/null; then
            evernode_status_output=$(evernode status 2>/dev/null)
            if [ -n "$evernode_status_output" ]; then
                # Look for "Available Lease offers: X out of Y" pattern and extract Y (total instances)
                # The \K in the regex discards everything before it, so we capture only Y
                auto_instance_count=$(echo "$evernode_status_output" | grep -oP 'Available Lease offers: \d+ out of \K\d+' 2>/dev/null)
            fi
        fi
        
        # In CRON_MODE, use auto-detected value or default to 1
        if [ $CRON_MODE -eq 1 ]; then
            if [ "$auto_instance_count" -gt 0 ]; then
                instance_count=$auto_instance_count
                echo "Using auto-detected instance count: $instance_count"
            else
                instance_count=1
                log_warning "Instance count not auto-detected, defaulting to 1"
            fi
        else
            # Interactive mode: Prompt with auto-detected value as default
            if [ "$auto_instance_count" -gt 0 ]; then
                echo "Auto-detected $auto_instance_count Evernode instance(s)"
                read -p "Press Enter to use this count, or enter a different number: " instance_count
                instance_count=${instance_count:-$auto_instance_count}
            else
                read -p "How many Evernode instances do you have? " instance_count
            fi
            
            if ! [[ "$instance_count" =~ ^[0-9]+$ ]] || [ "$instance_count" -lt 1 ]; then
                log_error "Invalid instance count. Must be a positive number"
                exit 1
            fi
        fi
        
        echo "Using instance count: $instance_count"

        required_ports=($(calculate_required_ports "$instance_count"))

        # Generate comprehensive report
        generate_report "$domain_name" "$lan_ip" "${required_ports[@]}"
    fi
    
    # Check Evernode host status
    check_evernode_host_status
    
    # Check Xahau WSS connection health
    check_xahau_wss_connection
    
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
    
    # Check Evernode logs (intensive operation, runs last)
    check_evernode_logs

    # JSON mode: emit the machine-readable report and exit with the
    # appropriate code, skipping the human-readable summary entirely.
    if [ $JSON_MODE -eq 1 ]; then
        print_json_report
        if [ $HAS_ERRORS -eq 1 ]; then
            exit 1
        elif [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
            exit 2
        else
            exit 0
        fi
    fi

    # Print summary report
    print_summary_report
    
    # Final status
    print_color "$BLUE" "\n====================================="
    print_color "$BLUE" "Health Check Complete"
    print_color "$BLUE" "====================================="
    
    if [ $HAS_ERRORS -eq 1 ]; then
        print_color "$RED" "\n⚠ ${#ERROR_MESSAGES[@]} error(s) detected - please review and address"
        print_color "$YELLOW" "   ${#WARNING_MESSAGES[@]} warning(s) - recommended to review"
        print_color "$GREEN" "   ${#SUCCESS_MESSAGES[@]} check(s) passed"
        exit 1
    else
        print_color "$GREEN" "\n✓ All checks passed successfully!"
        print_color "$GREEN" "   ${#SUCCESS_MESSAGES[@]} check(s) completed"
        if [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
            print_color "$YELLOW" "   ${#WARNING_MESSAGES[@]} warning(s) - optional improvements"
            # Distinct exit code so monitoring can tell "clean" from
            # "passing but with warnings".
            exit 2
        fi
    fi
}

# Run main function
main "$@"
