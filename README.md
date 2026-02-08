# Evernode Node Doctor

## Overview
The **Evernode Node Doctor** is a comprehensive, one-stop validation tool that verifies all requirements for running an Evernode node are properly met. This bash script performs exhaustive checks across system resources, Docker infrastructure, network configuration, security settings, and XRPL account balances to ensure your Evernode host is production-ready.

## Why Use This Tool?

Running an Evernode node requires meeting numerous technical requirements across multiple system components. This script automates the validation of ALL these requirements, helping you:

- **Pre-Installation Validation**: Verify your system meets all prerequisites before installing Evernode
- **Post-Installation Verification**: Confirm your Evernode installation is configured correctly
- **Troubleshooting**: Quickly identify configuration issues or missing requirements
- **Ongoing Monitoring**: Regular health checks to ensure continued operational readiness

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

### 8. Port Configuration & Accessibility
- Automatic port calculation based on instance count:
  - User ports: 22861+
  - Peer ports: 26201+
  - TCP ports: 36525+
  - UDP ports: 39064+
  - HTTP/HTTPS: 80, 443
- Nmap port scanning (domain and LAN)
- Port accessibility verification
- UFW rule validation for all required ports

### 9. XRPL Account Balance Verification (CRITICAL)
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

### 10. Evernode Host Status
- Retrieves current host status via Evernode CLI
- Registration status verification
- Host configuration display
- Operational status reporting

### 11. Comprehensive Error Handling
- Color-coded output (Blue/Green/Yellow/Red)
- Global error tracking
- Input validation for all prompts
- Command availability checking
- Graceful failure with actionable messages
- Exit codes indicating success/failure
- Final summary with pass/fail status

## Usage

### Basic Usage
1. Clone the repository or download the script:
   ```bash
   git clone https://github.com/Joshwaamein/evernode-node-doctor.git
   cd evernode-node-doctor
   ```

2. Make it executable:
   ```bash
   chmod +x evernode_health_check.sh
   ```

3. Run with sudo privileges (REQUIRED):
   ```bash
   sudo ./evernode_health_check.sh
   ```

### Interactive Prompts
During execution, the script will prompt you for:

1. **Domain name** of your Evernode host (REQUIRED)
   - Example: `myhost.example.com`

2. **Number of Evernode instances** (REQUIRED)
   - Used to calculate required ports
   - Example: `2`

3. **Evernode host account address** (OPTIONAL)
   - Auto-detected from config if available
   - Example: `rXXXXXXXXXXXXXXXXXXXXXXXXXXX`
   - Press Enter to skip if not applicable

4. **Evernode reputation account address** (OPTIONAL)
   - Auto-detected from config if available
   - Example: `rYYYYYYYYYYYYYYYYYYYYYYYYYYY`
   - Press Enter to skip if not applicable

### Use Cases

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

#### Regular Monitoring
Schedule periodic health checks:
```bash
# Add to crontab for weekly checks
0 2 * * 0 /path/to/evernode_health_check.sh > /var/log/evernode-health.log 2>&1
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

### Optional Tools
- `docker` - Container status checking
- `fail2ban` - Security monitoring
- `netstat` or `ss` - Port listening analysis

**Note:** The script will attempt to install missing dependencies automatically.

## Complete Validation Workflow

The script performs checks in the following order:

### Phase 1: Prerequisites & Dependencies
1. Root/sudo privilege verification
2. Automatic installation of missing dependencies (nmap, dig, curl, ufw, openssl, jq, docker.io)

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
26. Domain name input and DNS resolution
27. Public IP detection (gateway)
28. DNS-to-Gateway IP comparison
29. LAN IP detection
30. DNS mismatch identification

### Phase 8: Port Configuration
31. Instance count input and validation
32. Required ports calculation (user, peer, TCP, UDP, HTTP/HTTPS)
33. Nmap port scanning (domain)
34. Nmap port scanning (LAN IP)

### Phase 9: Firewall Configuration
35. UFW active status verification
36. UFW rule enumeration
37. Required port coverage analysis
38. Missing firewall rules identification

### Phase 10: SSL/TLS
39. SSL certificate retrieval
40. Certificate information display
41. Expiration date validation
42. Advance expiration warnings

### Phase 11: Evernode Status
43. Host status retrieval via Evernode CLI
44. Registration status display

### Phase 12: Account Balances (CRITICAL)
45. Host account balance check (XAH)
46. Host account EVR trust line detection
47. Host account EVR balance validation
48. Reputation account balance check (XAH)
49. Reputation account EVR balance validation
50. Threshold validation (50 XAH/EVR minimum recommended)

### Phase 13: Additional Security
51. fail2ban installation and status check

### Phase 14: Final Report
52. Overall health status summary
53. Error count reporting
54. Pass/fail determination
55. Exit with appropriate code (0=success, 1=errors detected)

## XRPL Account Balance Checking

The script now includes the ability to verify your Evernode host and reputation account balances:

- **XAH Balance**: Queries the XRPL network for native XAH balance
- **EVR Balance**: Checks for EVR trust lines and balances
- **Minimum Thresholds**: Warns if balances are below 50 XAH/EVR
- **API Source**: Uses public XRPL cluster API for reliable data

### Example Account Check Output
```
Checking balance for Host Account: rXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  XAH Balance: 125.50 XAH
  SUCCESS: Host Account has sufficient XAH balance (125.50 XAH)
  EVR Balance: 75.25 EVR
  SUCCESS: Host Account has sufficient EVR balance (75.25 EVR)
```

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

### Warnings (YELLOW)
- ⚠ Suboptimal configurations that should be addressed
- ⚠ Non-critical issues that won't prevent operation
- ⚠ Recommendations for improved security/performance
- ⚠ Account balances below recommended thresholds

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

### Evernode Installation Issues

**"Evernode CLI is not installed"**
- Follow the official Evernode installation guide
- Visit: https://github.com/EvernodeXRPL/evernode-host

**"Evernode service is not running"**
```bash
# Check service status
systemctl status evernode*

# Start the service
sudo systemctl start <evernode_service_name>
```

### Network Issues

**"Failed to resolve domain"**
- Verify your domain DNS records are configured
- Check DNS propagation: `dig +short yourdomain.com`
- Wait for DNS propagation (can take up to 48 hours)

**"DNS public IP mismatch"**
- Update your DNS A record to point to your server's public IP
- If behind NAT, configure port forwarding properly
- Verify with: `curl -s https://ipinfo.io/ip`

**"High latency"**
- Check your network connection
- Consider a different hosting provider with better connectivity
- Run traceroute to identify network bottlenecks

**"Unable to ping"**
- Check firewall rules (ICMP may be blocked)
- Verify internet connectivity
- Check if destination host is reachable

### Port & Firewall Issues

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

### SSL Certificate Issues

**"Failed to retrieve SSL certificate"**
- Ensure your domain is accessible via HTTPS
- Check if port 443 is open and forwarded
- Verify SSL certificate is properly installed
- Use Let's Encrypt for free certificates

**"SSL certificate has expired"**
- Renew your SSL certificate immediately
- Configure automatic renewal (e.g., certbot)

**"SSL certificate expires soon"**
- Renew certificate before expiration
- Set up monitoring/alerts for expiration

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

# Add weekly check (Sundays at 2 AM)
0 2 * * 0 /path/to/evernode_health_check.sh > /var/log/evernode-health.log 2>&1

# Add monthly full audit
0 3 1 * * /path/to/evernode_health_check.sh > /var/log/evernode-audit-$(date +\%Y\%m).log 2>&1
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is open source. Please check the repository for license details.

## Support

For issues specific to this script, please open an issue on GitHub.
For Evernode-related questions, visit the official Evernode documentation and community channels.

## Changelog

### Version 2.0 (Current)
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
