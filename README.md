# Evernode Node Doctor

## Overview
The **Evernode Node Doctor** is a comprehensive, one-stop validation tool that verifies all requirements for running an Evernode node are properly met. This bash script performs exhaustive checks across system resources, Docker infrastructure, network configuration, security settings, and XRPL account balances to ensure your Evernode host is production-ready.

## ✨ New Features (v2.6)

### 📋 Evernode Log Analysis
Automatically analyzes Evernode logs for errors, failures, and critical issues. Generates comprehensive logs via `evernode log` command and searches for problems. Includes 5-second warning and `--skip-logs` option to skip this intensive check.

## ✨ Features from v2.5

### 🤖 Cron Mode - Full Automation
Run the script in non-interactive mode for automated monitoring with complete auto-detection of all configuration values.

### 🔍 Port Usage Analysis
Advanced analysis showing which ports are open in firewall vs actually listening, with security warnings for open but unused ports (addresses the common issue of ports 80/443 being open but not in use).

### 📝 Port Purpose Documentation
Every port now includes a clear explanation of its purpose and what service should be using it.

### 🌐 Xahau WSS Health Check
Test your Xahau WebSocket connection using websocat (safe, no npm conflicts!) with automatic fallback to HTTPS API.

## Why Use This Tool?

Running an Evernode node requires meeting numerous technical requirements across multiple system components. This script automates the validation of ALL these requirements, helping you:

- **Pre-Installation Validation**: Verify your system meets all prerequisites before installing Evernode
- **Post-Installation Verification**: Confirm your Evernode installation is configured correctly
- **Troubleshooting**: Quickly identify configuration issues or missing requirements
- **Ongoing Monitoring**: Regular health checks to ensure continued operational readiness (with cron mode)
- **Security Auditing**: Identify open but unused ports and other security issues

## Comprehensive Validation Features

### 1. System Requirements Validation (CRITICAL)
- **CPU**: Minimum 4 cores required
- **RAM**: Minimum 8GB total RAM required
- **Disk Space**: Minimum 50GB free space recommended
- **Load Average**: System performance metrics
- Auto-detects and reports any deficiencies

### 2. Docker Infrastructure (CRITICAL - Required for Evernode)
- Docker installation verification
- Docker version reporting
- Docker service status (must be running)
- Container status monitoring
- Evernode (Sashimono) container detection and health
- Identifies stopped containers that should be running
- Docker disk usage analysis
- Provides installation/startup commands if issues found

### 3. Evernode Installation Validation
- Evernode CLI installation check
- Evernode version reporting
- Configuration directory verification
- Config file validation (config.json)
- Evernode systemd service status
- Host registration status
- Auto-detection of host and reputation accounts from config

### 4. System Health Monitoring
- System uptime and stability metrics
- Load average analysis
- Available vs. total RAM monitoring
- Low memory warnings

### 5. Network Connectivity & Performance
- Network latency testing to multiple endpoints (Google DNS, Cloudflare, Google)
- Acceptable latency threshold validation (<100ms)
- Internet connectivity verification
- DNS resolution testing

### 6. Security Configuration (CRITICAL)
- **SSH Security Audit**:
  - PermitRootLogin settings
  - PasswordAuthentication configuration
  - SSH port identification (standard vs non-standard)
- **Open Ports Analysis**:
  - Lists all listening ports
  - Identifies potentially vulnerable services (Telnet, FTP, RDP, VNC)
  - Security risk assessment
- **UFW Firewall**:
  - Active status verification
  - Required port configuration validation
  - Missing rules identification
  - Numbered rule display
- **SSL Certificate Validation**:
  - Certificate retrieval and display
  - Expiration date checking
  - Advance warning for certificates expiring <30 days
- **fail2ban**: Brute-force protection status

### 7. DNS & Network Configuration
- Domain name resolution
- Public IP detection and verification
- DNS to Gateway IP comparison
- LAN IP detection
- DNS mismatch detection and reporting

### 8. Port Configuration & Accessibility (🆕 ENHANCED)
- **Port Purpose Documentation**: Each port now displays its intended purpose
- **Port Usage Analysis**: Shows firewall status vs actual listening status
- **Security Warnings**: Flags ports that are open in firewall but nothing is listening
- **Process Detection**: Shows which service is using each port
- Automatic port calculation based on instance count:
  - User ports: 22861+
  - Peer ports: 26201+
  - TCP ports: 36525+
  - UDP ports: 39064+
  - HTTP/HTTPS: 80, 443
- Nmap port scanning (domain and LAN)
- Port accessibility verification
- UFW rule validation for all required ports

### 9. Xahau WSS Connection Health (🆕 NEW)
- **Automatic Endpoint Detection**: Reads WSS endpoint from config
- **WebSocket Testing**: Uses websocat (safe, no npm conflicts!)
- **HTTPS API Fallback**: Works even without websocat installed
- **Node Status**: Reports Xahau version, ledger sync, server state
- **Connection Validation**: Ensures your node can communicate with Xahau network

### 10. XRPL Account Balance Verification (CRITICAL)
- **Auto-Detection**: Reads accounts from Evernode config.json
- **Host Account Validation**:
  - XAH balance check (minimum 50 XAH recommended)
  - EVR trust line detection
  - EVR balance check (minimum 50 EVR recommended)
- **Reputation Account Validation**:
  - Same checks as host account
- **API Integration**: Uses public XRPL cluster API
- **Real-time Balance**: Queries validated ledger state
- **Insufficient Balance Warnings**: Clear alerts if below thresholds

### 11. Evernode Host Status
- Retrieves current host status via Evernode CLI
- Registration status verification
- Host configuration display
- Operational status reporting

### 12. Comprehensive Error Handling
- Color-coded output (Blue/Green/Yellow/Red)
- Global error tracking
- Input validation for all prompts
- Command availability checking
- Graceful failure with actionable messages
- Exit codes indicating success/failure
- Final summary with pass/fail status

## Usage

### Installation

1. Clone the repository or download the script:
   ```bash
   git clone https://github.com/Joshwaamein/evernode-node-doctor.git
   cd evernode-node-doctor
   ```

2. Make it executable:
   ```bash
   chmod +x evernode_health_check.sh
   ```

### Interactive Mode (Default)

Run with sudo privileges (REQUIRED):
```bash
sudo ./evernode_health_check.sh
```

During execution, the script will prompt you for:
1. **Domain name** of your Evernode host (REQUIRED) - Auto-detected if available
2. **Number of Evernode instances** (REQUIRED) - Auto-detected if available
3. **Evernode host account address** (OPTIONAL) - Auto-detected from config if available
4. **Evernode reputation account address** (OPTIONAL) - Auto-detected from config if available

### 🤖 Cron Mode (Non-Interactive - NEW!)

Run in fully automated mode with zero user interaction:

```bash
# Basic cron mode
sudo ./evernode_health_check.sh --cron

# Cron mode with log-friendly output (no color codes)
sudo ./evernode_health_check.sh --cron --no-color >> /var/log/evernode-health.log

# Skip account checks for faster execution
sudo ./evernode_health_check.sh --cron --skip-accounts

# Combine multiple flags
sudo ./evernode_health_check.sh --cron --no-color --skip-accounts
```

**Cron Mode Auto-Detection:**
- Domain name from `/etc/sashimono/reputationd/reputationd.cfg`
- Instance count from Docker containers or `evernode status`
- Host account from `/etc/sashimono/mb-xrpl/mb-xrpl.cfg`
- Reputation account from `/etc/sashimono/reputationd/reputationd.cfg`
- Gracefully skips checks if auto-detection fails

### Command-Line Options

```
--cron, --silent    Run in non-interactive mode (no prompts, auto-detect all values)
--no-color          Disable color output (useful for log files)
--skip-accounts     Skip XRPL account balance checks
--skip-logs         Skip Evernode log analysis (saves ~1-2 minutes)
--verbose           Show detailed debugging information
--help, -h          Show this help message
```

### Examples

#### Pre-Installation Check
Run this script BEFORE installing Evernode to verify your system meets all requirements:
```bash
sudo ./evernode_health_check.sh
```
This will check CPU, RAM, disk space, Docker availability, and more.

#### Post-Installation Verification
Run after installing Evernode to confirm everything is configured correctly:
```bash
sudo ./evernode_health_check.sh
```
The script will detect your Evernode installation and validate the configuration.

#### Troubleshooting
When experiencing issues with your Evernode node:
```bash
sudo ./evernode_health_check.sh
```
Review the output for any RED (error) or YELLOW (warning) messages.

#### Regular Monitoring with Cron
Schedule periodic health checks for automated monitoring:

**Daily Health Check (2 AM):**
```bash
# Add to crontab: sudo crontab -e
0 2 * * * /root/evernode-node-doctor/evernode_health_check.sh --cron --no-color >> /var/log/evernode-health.log 2>&1
```

**Hourly Quick Check (skip accounts for speed):**
```bash
0 * * * * /root/evernode-node-doctor/evernode_health_check.sh --cron --skip-accounts --no-color >> /var/log/evernode-hourly.log 2>&1
```

**Weekly Full Audit (with log rotation):**
```bash
0 3 * * 0 /root/evernode-node-doctor/evernode_health_check.sh --cron --no-color > /var/log/evernode-weekly-$(date +\%Y\%m\%d).log 2>&1
```

## Requirements

### Required Tools
- `sudo` privileges (must run as root)
- `nmap` - Network port scanning
- `dig` (dnsutils) - DNS resolution
- `curl` - HTTP requests and IP retrieval
- `ufw` - Firewall management
- `openssl` - SSL certificate checking
- `jq` - JSON parsing for XRPL API responses
- `bc` - Decimal calculations

### Optional Tools (Enhanced Features)
- `docker` - Container status checking
- `fail2ban` - Security monitoring
- `netstat` or `ss` - Port listening analysis
- `websocat` - WebSocket testing (for Xahau WSS health check)

**Note:** The script will attempt to install missing dependencies automatically.

## Port Usage Analysis (New Feature)

The enhanced port analysis provides a comprehensive view of your port configuration:

### Example Output:
```
=== Port Usage Analysis ===
Analyzing which ports are open in firewall vs actually listening...

Port Status Analysis:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Port     Firewall     Listening    Purpose
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
80       ALLOW        NO           HTTP: Let's Encrypt validation, HTTP-to-HTTPS redirect
  ⚠ SECURITY WARNING: Port open in firewall but nothing listening
443      ALLOW        YES          HTTPS: SSL/TLS termination (reverse proxy) (nginx)
22861    ALLOW        YES          Evernode User Port: WebSocket connections from tenants (docker)
26201    ALLOW        YES          Evernode Peer Port: Sashimono peer-to-peer communication (docker)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WARNING: 1 port(s) are open in firewall but not in use
Recommendation: Either start the required service or close the port with: sudo ufw delete allow <port>
```

### What It Tells You:
- **Port open but not listening (Evernode ports 22861+, 26201+, 36525+, 39064+)**: **This is EXPECTED BEHAVIOR** - these ports are pre-configured and services bind dynamically when instances are leased
- **Port open but not listening (ports 80/443)**: May indicate reverse proxy not running - start service or close port
- **Port listening with firewall deny**: Service is running but blocked - add firewall rule
- **Port listening with firewall allow**: Correct configuration ✓

### Important Note:
Evernode ports are designed to be open in the firewall even when not actively listening. Services bind to these ports dynamically when tenant instances are leased. This is normal and expected behavior.

## Xahau WSS Health Check (New Feature)

The script now tests your connection to the Xahau network:

### What It Checks:
- Xahau node connectivity (WebSocket and HTTPS API)
- Node version and build information
- Ledger synchronization status
- Server state (full, validating, proposing, syncing)

### Example Output:
```
=== Xahau WSS Connection Health Check ===
Configured Xahau WSS Endpoint: wss://xahau.network
Testing WebSocket connection with websocat...
SUCCESS: WSS connection to Xahau node is healthy
  Xahau Version: 2024.11.19+619
  Ledger Range: 1000000-1234567
  Server State: full
SUCCESS: Xahau node is fully synced
```

### Installation of websocat (Recommended):
```bash
# Get the latest version dynamically
LATEST_VERSION=$(curl -s https://api.github.com/repos/vi/websocat/releases/latest | jq -r .tag_name)

# Download pre-compiled binary from GitHub
sudo curl -L "https://github.com/vi/websocat/releases/download/${LATEST_VERSION}/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat

# Make it executable
sudo chmod +x /usr/local/bin/websocat

# Verify installation
websocat --version
```

**Or use the simplified one-liner:**
```bash
sudo curl -L "https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat && sudo chmod +x /usr/local/bin/websocat
```

**Note:** Websocat is not available in standard apt repositories. If websocat is not installed, the script automatically falls back to HTTPS API testing, which provides the same information.

## Complete Validation Workflow

The script performs checks in the following order:

### Phase 1: Prerequisites & Dependencies
1. Root/sudo privilege verification
2. Automatic installation of missing dependencies

### Phase 2: System Requirements (CRITICAL)
3. CPU core count validation (minimum 4 cores)
4. RAM capacity check (minimum 8GB total)
5. Available RAM monitoring (warns if <2GB available)
6. Disk space verification (minimum 50GB free recommended)
7. System uptime and load average display

### Phase 3: Core Infrastructure (CRITICAL)
8. Docker installation verification
9. Docker version reporting
10. Docker service status (must be running)
11. Docker container inventory
12. Evernode (Sashimono) container detection and health
13. Docker disk usage analysis

### Phase 4: Evernode Installation
14. Evernode CLI presence check
15. Evernode version identification
16. Configuration directory verification (~/.evernode)
17. Config file validation (config.json)
18. Evernode systemd service status
19. Auto-detection of account addresses from config

### Phase 5: Network Performance
20. Network latency testing (Google DNS, Cloudflare, Google)
21. Latency threshold validation (<100ms recommended)
22. Internet connectivity confirmation

### Phase 6: Security Audit
23. SSH configuration analysis (root login, password auth, port)
24. Open ports enumeration and security assessment
25. Vulnerable service detection (Telnet, FTP, RDP, VNC)

### Phase 7: Network Configuration
26. Domain name input and DNS resolution (auto-detected in cron mode)
27. Public IP detection (gateway)
28. DNS-to-Gateway IP comparison
29. LAN IP detection
30. DNS mismatch identification

### Phase 8: Port Configuration (🆕 ENHANCED)
31. Instance count input and validation (auto-detected in cron mode)
32. Required ports calculation (user, peer, TCP, UDP, HTTP/HTTPS)
33. **Port usage analysis** (firewall vs listening status)
34. **Port purpose documentation** (what each port does)
35. **Security warnings** (open but unused ports)
36. Nmap port scanning (domain and LAN)

### Phase 9: Firewall Configuration
37. UFW active status verification
38. UFW rule enumeration
39. Required port coverage analysis
40. Missing firewall rules identification

### Phase 10: SSL/TLS
41. SSL certificate retrieval
42. Certificate information display
43. Expiration date validation
44. Advance expiration warnings

### Phase 11: Evernode Status
45. Host status retrieval via Evernode CLI
46. Registration status display

### Phase 12: Xahau Connection (🆕 NEW)
47. Xahau WSS endpoint auto-detection
48. WebSocket connection test (using websocat)
49. Xahau node version and sync status
50. HTTPS API fallback if needed

### Phase 13: Account Balances (CRITICAL)
51. Host account balance check (XAH)
52. Host account EVR trust line detection
53. Host account EVR balance validation
54. Reputation account balance check (XAH)
55. Reputation account EVR balance validation
56. Threshold validation (50 XAH/EVR minimum recommended)

### Phase 14: Additional Security
57. fail2ban installation and status check

### Phase 15: Final Report
58. Overall health status summary
59. Error count reporting
60. Pass/fail determination
61. Exit with appropriate code (0=success, 1=errors detected)

## Output Color Coding

- 🔵 **BLUE**: Informational messages and section headers
- 🟢 **GREEN**: Successful checks and good configurations
- 🟡 **YELLOW**: Warnings and recommendations
- 🔴 **RED**: Errors and critical issues

## Exit Codes

- `0`: All checks passed successfully
- `1`: Errors detected during health check

## Understanding Results

### Success Indicators (GREEN)
- ✓ All system requirements met
- ✓ Docker running with healthy containers
- ✓ All required ports accessible
- ✓ UFW properly configured
- ✓ Sufficient account balances
- ✓ Valid SSL certificate
- ✓ Xahau node connection healthy

### Warnings (YELLOW)
- ⚠ Suboptimal configurations that should be addressed
- ⚠ Non-critical issues that won't prevent operation
- ⚠ Recommendations for improved security/performance
- ⚠ Account balances below recommended thresholds
- ⚠ Ports open in firewall but not in use (security risk)

### Errors (RED)
- ✗ Critical requirements not met
- ✗ Services not running (Docker, Evernode)
- ✗ Missing dependencies
- ✗ Configuration failures
- ✗ Network connectivity issues

## Troubleshooting Guide

### System Requirements Issues

**"CPU cores below recommended"**
- Your system needs at least 4 CPU cores for optimal Evernode performance
- Consider upgrading your hardware or choosing a different host

**"RAM below minimum requirements"**
- Evernode requires minimum 8GB RAM
- This is a CRITICAL requirement - upgrade your system before proceeding

**"Disk space below recommended"**
- You need at least 50GB free disk space
- Clean up unnecessary files or expand storage

**"Low available RAM"**
- Close unnecessary applications
- Check for memory leaks in running processes
- Consider adding more RAM

### Docker Issues

**"Docker is not installed"**
```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

**"Docker service is not running"**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**"Some Evernode containers are not running"**
```bash
# Check container status
docker ps -a --filter "name=sashimono"

# Restart stopped containers
docker start <container_name>

# Check logs for errors
docker logs <container_name>
```

### Port & Firewall Issues

**"Port open in firewall but nothing listening" (NEW WARNING)**
This is a security issue. Either:
1. Start the service that should be using the port:
   ```bash
   # For example, if nginx should be listening on port 80:
   sudo systemctl start nginx
   ```
2. Or close the unused port:
   ```bash
   sudo ufw delete allow <port>
   ```

**"UFW is inactive"**
```bash
# Enable UFW (WARNING: configure SSH access first!)
sudo ufw allow 22/tcp  # Or your SSH port
sudo ufw enable
```

**"Ports not configured in UFW"**
```bash
# Allow required Evernode ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22861:22865/tcp  # Adjust based on instance count
sudo ufw allow 26201:26205/tcp
# etc.
```

**"Nmap shows ports as closed"**
- Verify services are running on those ports
- Check UFW rules: `sudo ufw status numbered`
- Check router/firewall port forwarding
- Verify services are binding to correct interfaces

### Xahau Connection Issues (NEW)

**"Failed to connect to Xahau endpoint"**
- Check internet connectivity: `ping 8.8.8.8`
- Verify the endpoint in config: `cat /etc/sashimono/mb-xrpl/mb-xrpl.cfg | jq .xrpl.rippledServer`
- Try the public endpoint manually: `curl -X POST https://xahau.network -d '{"method":"server_info","params":[{}]}'`
- Check if firewall is blocking outbound connections

**"Xahau node state: syncing"**
- Node is still synchronizing with the network
- Wait for node to reach "full" state
- This is normal for new nodes or after downtime

**"websocat not installed"**
- Install it for better WSS testing: `sudo apt-get install websocat`
- The script will use HTTPS API fallback automatically

### Account Balance Issues

**"Unable to parse balance for account"**
- Verify the XRPL account address is correct (starts with 'r')
- Check if account exists on XRPL network
- Ensure internet connectivity to XRPL API
- Try again in a few moments (API may be temporarily unavailable)

**"Insufficient XAH balance"**
- Add more XAH to your account
- Minimum 50 XAH recommended for smooth operation
- Account needs reserves plus operational funds

**"Insufficient EVR balance"**
- Acquire more EVR tokens
- Check trust line is properly configured
- Minimum 50 EVR recommended

**"No EVR trust line found"**
- Set up EVR trust line in your XRPL wallet
- Required for Evernode host operations

### Permission Issues

**"Please run this script as root or with sudo"**
```bash
sudo ./evernode_health_check.sh
```

**"Unable to check UFW status"**
- Ensure you have sudo privileges
- Run script with sudo

### General Troubleshooting Tips

1. **Read the entire output** - Issues often provide context
2. **Check logs** - Docker logs, system logs, Evernode logs
3. **Verify basics first** - Internet connection, DNS, firewall
4. **One issue at a time** - Fix critical errors before warnings
5. **Rerun after fixes** - Verify each fix by running the script again
6. **Use cron mode for monitoring** - Automate regular checks

## Security Best Practices

### SSH Hardening
```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Recommended settings:
PermitRootLogin no
PasswordAuthentication no
Port 2222  # Use non-standard port

# Restart SSH
sudo systemctl restart sshd
```

### Firewall Configuration
```bash
# Start with deny all
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (adjust port if changed)
sudo ufw allow 22/tcp

# Allow Evernode required ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22861:22870/tcp  # Adjust range based on instances
sudo ufw allow 26201:26210/tcp
sudo ufw allow 36525:36550/tcp
sudo ufw allow 39064:39100/udp

# Enable firewall
sudo ufw enable
```

### Port Management
Use the port usage analysis feature to identify and close unused open ports:
```bash
# Run the health check to see which ports are open but unused
sudo ./evernode_health_check.sh

# Close any unused ports
sudo ufw delete allow <port>
```

### Fail2ban Setup
```bash
# Install fail2ban
sudo apt-get install -y fail2ban

# Configure and start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Check status
sudo fail2ban-client status
```

### SSL/TLS Certificates
```bash
# Install certbot for Let's Encrypt
sudo apt-get install -y certbot

# Obtain certificate
sudo certbot certonly --standalone -d yourdomain.com

# Set up auto-renewal
sudo systemctl enable certbot.timer
```

### Account Security
- Never share private keys
- Use strong, unique passwords for XRPL accounts
- Store seed phrases securely offline
- Enable 2FA on any accounts accessing your XRPL accounts
- Regularly monitor account activity
- Maintain adequate but not excessive balances

### Regular Monitoring
```bash
# Schedule regular health checks
sudo crontab -e

# Add daily check (2 AM)
0 2 * * * /root/evernode-node-doctor/evernode_health_check.sh --cron --no-color >> /var/log/evernode-health.log 2>&1

# Add monthly full audit
0 3 1 * * /root/evernode-node-doctor/evernode_health_check.sh --cron > /var/log/evernode-audit-$(date +\%Y\%m).log 2>&1
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is open source. Please check the repository for license details.

## Support

For issues specific to this script, please open an issue on GitHub.
For Evernode-related questions, visit the official Evernode documentation and community channels.

## Changelog

### Version 2.6 (Current)
- **Added Evernode Log Analysis**: Analyzes `evernode log` output for errors and failures
- **Added --skip-logs Flag**: Skip intensive log generation (saves 1-2 minutes)
- **Added Early Warning System**: 5-second countdown before starting checks
- **Added Options Display**: Shows available flags at script start
- **Added ASCII Art Banner**: Professional "EVERNODE NODE DOCTOR" header

### Version 2.5
- **Added Cron Mode**: Fully automated non-interactive mode with complete auto-detection
- **Added Port Usage Analysis**: Shows firewall vs listening status with security warnings
- **Added Port Purpose Documentation**: Clear explanations for each port's purpose
- **Added Xahau WSS Health Check**: Test WebSocket connection using websocat (safe, no npm)
- **Added Command-Line Arguments**: --cron, --no-color, --skip-accounts, --verbose, --help
- **Enhanced Auto-Detection**: Domain, instance count, and accounts from config files
- **Improved Logging**: Better suited for log files with --no-color option

### Version 2.0
- Complete rewrite with comprehensive validation
- Added system requirements checking (CPU, RAM, disk)
- Added Docker infrastructure validation
- Added Evernode installation verification
- Added XRPL account balance checking with auto-detection
- Enhanced security audits
- Improved error handling and reporting
- Added detailed troubleshooting documentation

### Version 1.0 (Original)
- Basic DNS and port checking
- UFW configuration display
- System resource assessment