# Evernode Node Doctor - New Features Quick Reference

## 🚀 Version 3.1 Features (end-to-end / diagnostics)

Complementary to the external community tester at
https://api.onledger.net/host-test (which probes from outside and proves
domain ownership). This local tool adds, on-host:

- **Virtualisation detection** (`systemd-detect-virt`).
- **Reputation contract opt-in** as an explicit PASS/FAIL line.
- **Instance-slot zombie detection** (read-only): `sa.sqlite` "running"
  rows vs live Docker containers. A zombie slot is the classic cause of
  sustained reputation collapse.
- **`--report <path>`**: shareable, self-contained diagnostic file.
- **`--external`** (opt-in) + **`--reflector <url>`**: honest external
  port-reachability via a public reflector. Off by default (shares your
  public IP:port). Local nmap is never relabelled as external.
- **Optional Node helper `gp-probe.js`**: real TLS handshake on the
  user/GP port (the WAN-hairpin path reputationd uses) and the real
  GP/HotPocket peer handshake when the Evernode client lib is present.
  If Node.js is absent, these are skipped with install instructions,
  never faked. Disable with **`--no-gp-probe`**.

Deliberately not done: on-demand HotPocket instance spin-up (zombie-slot
risk) and a bash fake of the peer-visa/GP protocol. For an authoritative
external + cluster handshake, use the onledger.net service.

## 🚀 Version 3.0 Features

### 1. Command-Line Flags Now Apply (critical fix)

**Purpose**: Make every documented flag actually take effect.

**What Changed:**
- Previous versions invoked `main` without forwarding `"$@"`, so
  `--cron`, `--no-color`, `--skip-accounts`, `--skip-logs`, and `--help`
  were silently ignored on a normal run. The flags now work.

**Why This Matters:**
- Documented cron jobs were running in interactive mode, not cron mode.
- `--help` now prints usage and exits instead of running a full check.

---

### 2. JSON Output (`--json`) for Monitoring

**Purpose**: Emit a machine-readable summary for monitoring pipelines.

**Usage:**
```bash
sudo ./evernode_health_check.sh --json
```

**What It Does:**
- Implies `--cron` and `--no-color` (no prompts, no ANSI codes).
- Prints a single JSON object: overall status, counts, and the success /
  warning / error message lists. Content is escaped via `jq`.

**Example Output:**
```json
{
  "status": "warning",
  "timestamp": "2026-06-16T10:23:20Z",
  "host": "evernode-host",
  "counts": { "success": 41, "warning": 2, "error": 0 },
  "successes": ["Docker service is running", "..."],
  "warnings": ["Disk space below recommended (40GB available...)", "..."],
  "errors": []
}
```

**Exit Codes (JSON and normal runs):**
- `0`: all checks clean
- `1`: one or more errors
- `2`: passing, but with warnings

---

### 3. Balance Checks Use Your Node's Endpoint

**Purpose**: Query balances through your own Xahau node, accurately.

**What Changed:**
- The JSON-RPC endpoint is derived from your configured `rippledServer`
  in `/etc/sashimono/mb-xrpl/mb-xrpl.cfg`, falling back to the public
  Xahau RPC only if your node is unreachable.
- Fixed a dead variable that shadowed the real EVR trustline read, so the
  EVR balance is now reported correctly (from the canonical Evernode
  issuer `rEvernodee8dJLaFsujS6q1EiXvZYmHXr8`).
- Added `actNotFound` handling, signed-balance normalisation, and a basic
  address-format check.

**Note on thresholds:** the 50 XAH / 50 EVR figures are recommended
operator **buffers**, not the protocol reserve minimum. The protocol
minimum is the Xahau base reserve plus per-owned-object increments.

---

### 4. Correct Xahau Sync States

**Purpose**: Don't false-alarm on a healthy validator.

**What Changed:**
- Accepts `full`, `proposing`, or `validating` as healthy synced states
  (a validator legitimately reports proposing/validating). This reverts
  the over-strict v2.6 "full only" behaviour.
- Only `syncing`, `connected`, and `tracking` raise an error.

**Example Output:**
```
Server State: proposing
✓ Xahau node is synced and healthy (server_state: proposing)

# Not yet ready:
Server State: syncing
✗ ERROR: Xahau node not fully synced (server_state: syncing).
  Must reach full/proposing/validating before accepting tenants
```

---

### 5. Correct Port Maths

**Purpose**: Compute and label the right ports for any instance count.

**What Changed:**
- Fixed an off-by-one in the per-instance port calculation.
- Included the UDP port range, which was previously dropped from the
  required-ports set.
- `get_port_purpose` is now range-based, so hosts with more than ~10
  instances no longer report "Unknown port".

---

### 6. Cron-Safe Dependencies and Hardening

**Purpose**: Behave well when run unattended.

**What Changed:**
- Installs only the tools that are actually missing, and in
  `--cron`/`--json` mode never runs `apt-get` (no apt-lock contention
  with `unattended-upgrades`); it warns and continues with degraded
  checks instead.
- Added `set -uo pipefail` for safer failure behaviour.
- Added an MIT `LICENSE` file.

---

## 🚀 Version 2.6 Features

### 1. Xahau Node State Validation

**Purpose**: Confirm the Xahau node is synced before accepting tenants.

> Note: v2.6 made this "full only". v3.0 corrected it to also accept
> `proposing` and `validating` (see the v3.0 section above).

**Example Output:**
```
Server State: full
✓ Xahau node is synced and healthy (server_state: full)
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
- **22861+**: Evernode User Ports, 1 per instance (WebSocket connections from tenants)
- **26201+**: Evernode Peer Ports, 1 per instance (Sashimono P2P)
- **36525+**: Evernode TCP Ports, 2 per instance (Tenant TCP communication)
- **39064+**: Evernode UDP Ports, 2 per instance (Tenant UDP communication)

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
| `--skip-logs` | - | Skip Evernode log analysis (saves ~1-2 minutes) |
| `--verbose` | - | Show detailed debugging info |
| `--json` | - | Machine-readable JSON summary (implies `--cron` + `--no-color`) |
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
0 2 * * * /opt/evernode-node-doctor/evernode_health_check.sh --cron --no-color >> /var/log/evernode-daily.log 2>&1
```

**2. Hourly Quick Check (skip accounts):**
```bash
0 * * * * /opt/evernode-node-doctor/evernode_health_check.sh --cron --skip-accounts --no-color >> /var/log/evernode-hourly.log 2>&1
```

**3. Weekly Full Audit (Sundays at 3 AM):**
```bash
0 3 * * 0 /opt/evernode-node-doctor/evernode_health_check.sh --cron --no-color > /var/log/evernode-weekly-$(date +\%Y\%m\%d).log 2>&1
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