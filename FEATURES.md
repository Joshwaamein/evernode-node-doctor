# Evernode Node Doctor - New Features Quick Reference

## 🚀 Version 2.6 Features

### 1. Strict Xahau Node State Validation

**Purpose**: Ensure Xahau node is in "full" state before accepting tenant instances.

**What Changed:**
- Previously accepted: `full`, `validating`, or `proposing`
- Now requires: **`full` ONLY**

**Why This Matters:**
- Ensures node is fully synchronized with the Xahau blockchain
- Prevents issues with tenant instances on partially synced nodes
- Provides clearer error messages when node is not ready

**Example Output:**
```
Server State: full
✓ Xahau node is fully synced (server_state: full)

# If not "full":
Server State: syncing
✗ ERROR: Xahau node state: syncing (MUST be 'full' to work properly)
```

---

### 2. API Version 1 Support

**Purpose**: Enhanced Xahau node validation with dedicated API version 1 check.

**What It Does:**
- Adds a separate `server_info` check using `api_version: 1` parameter
- Provides additional verification layer for node connectivity
- Auto-detects Xahau endpoint from config file

**Check Sequence:**
1. **Method 1**: WebSocket test using websocat (if available)
2. **Method 2**: HTTPS API with `api_version: 1` ✨ NEW
3. **Method 3**: Standard HTTPS API fallback

**Example Output:**
```
=== Xahau WSS Connection Health Check ===
Configured Xahau WSS Endpoint: wss://xahau.network

Testing server_info with API version 1...
✓ Server info check with API version 1 successful
  Server State (API v1): full
✓ Xahau node is fully synced (server_state: full)
  Xahau Version: 2024.11.19+619
  Ledger Range: 1000000-1234567
```

**Configuration:**
The script automatically reads your configured endpoint from:
`/etc/sashimono/mb-xrpl/mb-xrpl.cfg`

No manual configuration needed!

---

### 3. Enhanced Multi-Method Validation

**Purpose**: Multiple validation methods ensure robust connectivity checking.

**Three-Tier Approach:**
1. **WebSocket (websocat)**: Fastest, most reliable if websocat installed
2. **API v1 (HTTPS)**: Enhanced validation with explicit API version
3. **Standard API (HTTPS)**: Fallback for maximum compatibility

**Benefits:**
- ✅ Works even if websocat not installed
- ✅ Multiple validation points for confidence
- ✅ Clear indication which method succeeded
- ✅ Detailed error messages if all methods fail

---

## 🚀 Version 2.5 Features

### 1. Cron Mode (`--cron`)

**Purpose**: Run the script fully automated without any user prompts.

**Usage:**
```bash
# Basic automated run
sudo ./evernode_health_check.sh --cron

# With log output (no colors)
sudo ./evernode_health_check.sh --cron --no-color >> /var/log/evernode.log

# Skip account checks for speed
sudo ./evernode_health_check.sh --cron --skip-accounts
```

**Auto-Detects:**
- ✅ Domain from `/etc/sashimono/reputationd/reputationd.cfg`
- ✅ Instance count from Docker containers
- ✅ Host account from config
- ✅ Reputation account from config

**Fallback Behavior:**
- Skips checks gracefully if detection fails
- Logs warnings for missing values
- Defaults to sensible values (instance_count=1)

---

### 2. Port Usage Analysis

**Purpose**: Identify security issues where ports are open in firewall but nothing is listening.

**What You'll See:**
```
Port     Firewall     Listening    Purpose
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
80       ALLOW        NO           HTTP: Let's Encrypt validation
  ⚠ SECURITY WARNING: Port open but nothing listening
443      ALLOW        YES          HTTPS: SSL/TLS termination (nginx)
22861    ALLOW        YES          Evernode User Port (docker)
```

**What It Means:**
- **ALLOW + NO (Evernode ports)**: ✓ **EXPECTED BEHAVIOR** - Ports pre-configured, services bind when instances leased
- **ALLOW + NO (ports 80/443)**: May need reverse proxy running or can close if not needed
- **ALLOW + YES**: ✓ Correct configuration - service is running
- **DENY + YES**: Service blocked by firewall - needs firewall rule

**Important Note:**
Evernode ports (22861+, 26201+, 36525+, 39064+) are designed to be open in the firewall even when not actively listening. Services bind to these ports dynamically when tenant instances are leased. **This is normal and expected behavior.**

**Action Items (for ports 80/443 only):**
```bash
# If you use a reverse proxy, start it
sudo systemctl start nginx

# If you don't need HTTP/HTTPS, close them
sudo ufw delete allow 80
sudo ufw delete allow 443
```

---

### 3. Port Purpose Documentation

**Purpose**: Understand what each port is for and why it's needed.

**Port Categories:**
- **80**: HTTP (Let's Encrypt validation, HTTP-to-HTTPS redirect)
- **443**: HTTPS (SSL/TLS termination via reverse proxy)
- **22861-22870**: Evernode User Ports (WebSocket connections from tenants)
- **26201-26210**: Evernode Peer Ports (Sashimono P2P)
- **36525-36540**: Evernode TCP Ports (Tenant TCP communication)
- **39064-39080**: Evernode UDP Ports (Tenant UDP communication)

**Common Questions:**
- **Q: Why is port 80/443 open but not in use?**
  - A: These are for reverse proxy (nginx/caddy). Either install the proxy or close the ports.

---

### 4. Xahau WSS Health Check

**Purpose**: Verify your Evernode node can communicate with the Xahau blockchain network.

**What It Tests:**
- WebSocket connection to Xahau node
- Node version and build
- Ledger synchronization status
- Server state (full, validating, syncing)

**Example Output:**
```
Configured Xahau WSS Endpoint: wss://xahau.network
Testing WebSocket connection with websocat...
✓ WSS connection to Xahau node is healthy
  Xahau Version: 2024.11.19+619
  Ledger Range: 1000000-1234567
  Server State: full
✓ Xahau node is fully synced
```

**Installation (Recommended):**
```bash
# One-liner to install latest version
sudo curl -L "https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat && sudo chmod +x /usr/local/bin/websocat

# Verify installation
websocat --version
```

**Or get latest version explicitly:**
```bash
LATEST_VERSION=$(curl -s https://api.github.com/repos/vi/websocat/releases/latest | jq -r .tag_name)
sudo curl -L "https://github.com/vi/websocat/releases/download/${LATEST_VERSION}/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat
sudo chmod +x /usr/local/bin/websocat
```

**Note:** Websocat is not in standard apt repositories, but the binary installation is simple and safe.

**Safety:**
- ✅ Uses websocat (NOT wscat - no npm conflicts!)
- ✅ Read-only operation (no state changes)
- ✅ Falls back to HTTPS API if websocat unavailable
- ✅ Safe to run while Evernode is running

---

## Command-Line Options Reference

### All Available Flags:

| Flag | Alias | Description |
|------|-------|-------------|
| `--cron` | `--silent` | Non-interactive mode (no prompts) |
| `--no-color` | - | Disable color output for logs |
| `--skip-accounts` | - | Skip XRPL account balance checks |
| `--verbose` | - | Show detailed debugging info |
| `--help` | `-h` | Show help message |

### Common Combinations:

```bash
# Daily cron job (most common)
sudo ./evernode_health_check.sh --cron --no-color

# Quick health check (skip slow checks)
sudo ./evernode_health_check.sh --cron --skip-accounts

# Full verbose debug
sudo ./evernode_health_check.sh --verbose

# Interactive with account skip
sudo ./evernode_health_check.sh --skip-accounts
```

---

## Cron Job Examples

### Recommended Setup:

**1. Daily Full Health Check (2 AM):**
```bash
0 2 * * * /root/evernode-node-doctor/evernode_health_check.sh --cron --no-color >> /var/log/evernode-daily.log 2>&1
```

**2. Hourly Quick Check (skip accounts):**
```bash
0 * * * * /root/evernode-node-doctor/evernode_health_check.sh --cron --skip-accounts --no-color >> /var/log/evernode-hourly.log 2>&1
```

**3. Weekly Full Audit (Sundays at 3 AM):**
```bash
0 3 * * 0 /root/evernode-node-doctor/evernode_health_check.sh --cron --no-color > /var/log/evernode-weekly-$(date +\%Y\%m\%d).log 2>&1
```

### Log Rotation:

Add to `/etc/logrotate.d/evernode-doctor`:
```
/var/log/evernode*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## Migration from v2.0 to v2.5

### What Changed:
- ✅ **No breaking changes** - all existing functionality preserved
- ✅ New features are opt-in via command-line flags
- ✅ Interactive mode works exactly the same as before
- ✅ New features enhance, don't replace

### What You Get:
1. **Better automation** with cron mode
2. **Better security insights** with port usage analysis
3. **Better understanding** with port purpose documentation
4. **Better connectivity validation** with Xahau WSS check

### Recommended Actions:
1. Test the script in interactive mode first
2. Set up cron jobs for automated monitoring
3. Review port usage analysis output
4. Install websocat for better WSS testing

---

## Testing Checklist

Before deploying to production:

- [ ] Test interactive mode: `sudo ./evernode_health_check.sh`
- [ ] Test cron mode: `sudo ./evernode_health_check.sh --cron`
- [ ] Test with --no-color: `sudo ./evernode_health_check.sh --cron --no-color`
- [ ] Verify port analysis shows correct results
- [ ] Check Xahau WSS connection works
- [ ] Verify account detection works
- [ ] Test on actual Evernode server
- [ ] Set up cron job
- [ ] Monitor logs for issues

---

## Key Benefits

### For Users:
- 🔍 **Better visibility** into what ports are actually being used
- 🔒 **Better security** by identifying open but unused ports
- 🤖 **Full automation** for monitoring with cron mode
- 📊 **Clear documentation** explaining each port's purpose

### For Troubleshooting:
- Quickly identify if port 80/443 should be open or closed
- See exactly which service is listening on each port
- Understand the purpose of each Evernode port
- Verify Xahau connectivity without affecting production

### For Production:
- Zero-downtime monitoring with cron mode
- Safe WSS testing (no npm conflicts)
- Automated alerts via exit codes
- Log-friendly output for analysis tools

---

## FAQ

**Q: Will cron mode work if my domain isn't in the config?**
A: Yes, it will skip domain-based checks and log a warning.

**Q: Is it safe to run while Evernode is running?**
A: Yes, all checks are read-only and don't affect running services.

**Q: Will websocat conflict with Evernode like wscat did?**
A: No, websocat is a standalone Rust binary with no npm dependencies.

**Q: Do I need to use cron mode?**
A: No, interactive mode still works. Cron mode is optional for automation.

**Q: What if port analysis shows ports I don't recognize?**
A: Check the "Purpose" column - it explains what each port is for.

**Q: Should I close port 80 if nothing is listening?**
A: Depends on your setup. If you don't use Let's Encrypt or HTTP redirects, you can close it.