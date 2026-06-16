#!/usr/bin/env bash
#
# Evernode Node Doctor - installer.
# Drops the doctor script + Node helper into a target dir and (optionally)
# adds a daily cron entry. Safe to re-run (idempotent).
#
# Quick use:
#   curl -fsSL https://raw.githubusercontent.com/Joshwaamein/evernode-node-doctor/main/install.sh | sudo bash
#
# Options (env vars):
#   INSTALL_DIR  (default /opt/evernode-node-doctor)
#   ADD_CRON=1   add a daily 02:00 --cron health check to root's crontab
#   BRANCH       (default main)

set -uo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/evernode-node-doctor}"
BRANCH="${BRANCH:-main}"
RAW="https://raw.githubusercontent.com/Joshwaamein/evernode-node-doctor/${BRANCH}"
ADD_CRON="${ADD_CRON:-0}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo)." >&2
    exit 1
fi

echo "Installing Evernode Node Doctor to ${INSTALL_DIR} (branch: ${BRANCH})"
mkdir -p "$INSTALL_DIR"

fetch() {
    local name=$1
    if ! curl -fsSL "${RAW}/${name}" -o "${INSTALL_DIR}/${name}"; then
        echo "Failed to download ${name}" >&2
        exit 1
    fi
}

fetch evernode_health_check.sh
fetch gp-probe.js
chmod +x "${INSTALL_DIR}/evernode_health_check.sh" "${INSTALL_DIR}/gp-probe.js"

echo "Installed:"
echo "  ${INSTALL_DIR}/evernode_health_check.sh"
echo "  ${INSTALL_DIR}/gp-probe.js"

if [ "$ADD_CRON" = "1" ]; then
    cron_line="0 2 * * * ${INSTALL_DIR}/evernode_health_check.sh --cron --no-color >> /var/log/evernode-health.log 2>&1"
    # Add only if not already present.
    if crontab -l 2>/dev/null | grep -Fq "${INSTALL_DIR}/evernode_health_check.sh"; then
        echo "Cron entry already present; leaving it as-is."
    else
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        echo "Added daily 02:00 cron health check (logs to /var/log/evernode-health.log)."
    fi
fi

echo ""
echo "Run it:  sudo ${INSTALL_DIR}/evernode_health_check.sh"
echo "Help:    sudo ${INSTALL_DIR}/evernode_health_check.sh --help"
