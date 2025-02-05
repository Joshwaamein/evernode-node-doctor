# Evernode Health Check Script

## Overview
This bash script performs a comprehensive health check for an Evernode appliance, including DNS configuration, port accessibility, firewall settings, system resources, and security features.

## Features
- DNS resolution and public IP verification
- Port checking for Evernode instances
- UFW (Uncomplicated Firewall) configuration display
- fail2ban installation check
- System resource assessment (CPU, RAM, disk space)

## Usage
1. Save the script as `evernode_health_check.sh`
2. Make it executable:
chmod +x evernode_health_check.sh
text
3. Run with sudo privileges:
sudo ./evernode_health_check.sh
text

## Requirements
- `nmap`
- `dig`
- `curl`
- `ufw`
- `sudo` privileges

## Script Workflow
1. Prompt for domain name and resolve IP
2. Check public IP of gateway
3. Calculate and check required ports
4. Display UFW configuration
5. Check fail2ban status
6. Assess system resources

## System Resource Checks
- CPU cores
- Total and available RAM
- Available disk space
