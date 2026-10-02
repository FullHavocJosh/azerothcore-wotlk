#!/bin/bash
#
# Install AzerothCore Systemd Services and Timers
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$PROJECT_DIR/systemd"
SYSTEM_SYSTEMD_DIR="/etc/systemd/system"

echo "========================================="
echo "Installing AzerothCore Systemd Services"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Load environment to show what we're installing
source "$PROJECT_DIR/.env"
echo "Environment: $ENV_NAME"
echo ""

# Copy service files
echo "Installing service files..."
cp "$SYSTEMD_DIR/azerothcore.service" "$SYSTEM_SYSTEMD_DIR/"
cp "$SYSTEMD_DIR/azerothcore-shutdown.service" "$SYSTEM_SYSTEMD_DIR/"
cp "$SYSTEMD_DIR/azerothcore-backup.service" "$SYSTEM_SYSTEMD_DIR/"
echo "✓ Service files installed"
echo ""

# Copy timer files
echo "Installing timer files..."
cp "$SYSTEMD_DIR/azerothcore-shutdown.timer" "$SYSTEM_SYSTEMD_DIR/"
cp "$SYSTEMD_DIR/azerothcore-ensure-off.timer" "$SYSTEM_SYSTEMD_DIR/"
cp "$SYSTEMD_DIR/azerothcore-backup.timer" "$SYSTEM_SYSTEMD_DIR/"
echo "✓ Timer files installed"
echo ""

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"
echo ""

echo "========================================="
echo "Installation Complete"
echo "========================================="
echo ""
echo "Available services:"
echo "  azerothcore.service           - Main container management"
echo "  azerothcore-shutdown.service  - Shutdown containers"
echo "  azerothcore-backup.service    - Database backups"
echo ""
echo "Available timers:"
echo "  azerothcore-shutdown.timer    - Daily shutdown at 4 PM"
echo "  azerothcore-ensure-off.timer  - Ensure off 5-11 PM"
echo "  azerothcore-backup.timer      - Daily backup at 11 PM (before server shutdown)"
echo ""
echo "Recommended next steps:"
echo ""

if [ "$ENV_NAME" = "testing" ]; then
    echo "For TESTING environment:"
    echo "  1. Enable auto-start at boot:"
    echo "     systemctl enable azerothcore.service"
    echo ""
    echo "  2. Enable shutdown timers:"
    echo "     systemctl enable --now azerothcore-shutdown.timer"
    echo "     systemctl enable --now azerothcore-ensure-off.timer"
    echo ""
    echo "  3. Start containers now (if before 4 PM):"
    echo "     systemctl start azerothcore.service"
    echo ""
    echo "  Note: Backup timer NOT needed on testing (ENABLE_DB_BACKUPS=false)"
    echo ""
elif [ "$ENV_NAME" = "production" ]; then
    echo "For PRODUCTION environment:"
    echo "  1. Enable auto-start at boot:"
    echo "     systemctl enable azerothcore.service"
    echo ""
    echo "  2. Enable backup timer (IMPORTANT - runs at 11 PM before server shutdown):"
    echo "     systemctl enable --now azerothcore-backup.timer"
    echo ""
    echo "  3. Start containers now:"
    echo "     systemctl start azerothcore.service"
    echo ""
    echo "  Note: Host server shuts down at 11:59 PM daily"
    echo "        Backup runs at 11:00 PM to complete before shutdown"
    echo ""
fi

echo "Manual control commands:"
echo "  systemctl start azerothcore    - Start containers"
echo "  systemctl stop azerothcore     - Stop containers"
echo "  systemctl status azerothcore   - Check status"
echo "  systemctl restart azerothcore  - Restart containers"
echo ""
echo "View logs:"
echo "  journalctl -u azerothcore -f"
echo "  journalctl -u azerothcore-shutdown -f"
echo "  journalctl -u azerothcore-backup -f"
echo ""
echo "List timers:"
echo "  systemctl list-timers"
