#!/bin/bash
#
# Uninstall AzerothCore Systemd Services and Timers
#

set -e

SYSTEM_SYSTEMD_DIR="/etc/systemd/system"

echo "========================================="
echo "Uninstalling AzerothCore Systemd Services"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Stop and disable services
echo "Stopping and disabling services..."
systemctl stop azerothcore.service 2>/dev/null || true
systemctl disable azerothcore.service 2>/dev/null || true

systemctl stop azerothcore-shutdown.timer 2>/dev/null || true
systemctl disable azerothcore-shutdown.timer 2>/dev/null || true

systemctl stop azerothcore-ensure-off.timer 2>/dev/null || true
systemctl disable azerothcore-ensure-off.timer 2>/dev/null || true

systemctl stop azerothcore-backup.timer 2>/dev/null || true
systemctl disable azerothcore-backup.timer 2>/dev/null || true

echo "✓ Services stopped and disabled"
echo ""

# Remove service files
echo "Removing service files..."
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore.service"
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore-shutdown.service"
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore-backup.service"
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore-shutdown.timer"
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore-ensure-off.timer"
rm -f "$SYSTEM_SYSTEMD_DIR/azerothcore-backup.timer"
echo "✓ Service files removed"
echo ""

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload
systemctl reset-failed
echo "✓ Systemd daemon reloaded"
echo ""

echo "========================================="
echo "Uninstallation Complete"
echo "========================================="
