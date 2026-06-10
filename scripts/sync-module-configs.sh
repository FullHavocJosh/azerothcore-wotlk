#!/usr/bin/env bash
set -euo pipefail

# Script: sync-module-configs.sh
# Purpose: Intelligently merge module .conf.dist updates into custom .conf files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_ROOT/modules"
CONF_DIR="$PROJECT_ROOT/env/dist/etc/modules"
BACKUP_DIR="$PROJECT_ROOT/env/dist/etc/modules/.backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Extract custom values using awk (more reliable than while read)
extract_custom_values() {
    local conf_file="$1"
    local dist_file="$2"
    
    if [[ ! -f "$conf_file" ]] || [[ ! -f "$dist_file" ]]; then
        return 0
    fi
    
    # Use awk to extract settings that differ from default
    awk -F'=' '
    BEGIN {
        # Read dist file defaults
        while ((getline line < "'$dist_file'") > 0) {
            if (line ~ /^[[:space:]]*[^#].*=/) {
                sub(/^[[:space:]]+/, "", line)
                split(line, parts, "=")
                key = parts[1]
                sub(/[[:space:]]+$/, "", key)
                value = parts[2]
                for (i=3; i<=length(parts); i++) value = value "=" parts[i]
                sub(/^[[:space:]]+/, "", value)
                defaults[key] = value
            }
        }
    }
    {
        # Process conf file
        if (/^[[:space:]]*[^#].*=/) {
            sub(/^[[:space:]]+/, "")
            split($0, parts, "=")
            key = parts[1]
            sub(/[[:space:]]+$/, "", key)
            value = parts[2]
            for (i=3; i<=length(parts); i++) value = value "=" parts[i]
            sub(/^[[:space:]]+/, "", value)
            
            # If value differs from default, output it
            if (key in defaults && value != defaults[key]) {
                print key "=" value
            }
        }
    }
    ' "$conf_file"
}

# Apply custom values using sed
apply_custom_values() {
    local dist_file="$1"
    local custom_values="$2"
    local output_file="$3"
    
    cp "$dist_file" "$output_file"
    
    if [[ ! -f "$custom_values" ]] || [[ ! -s "$custom_values" ]]; then
        return 0
    fi
    
    while IFS='=' read -r key value; do
        # Escape special characters for sed
        escaped_value=$(echo "$value" | sed 's/[&/\]/\\&/g')
        sed -i "s|^\([[:space:]]*${key}[[:space:]]*=\).*|\1 $escaped_value|" "$output_file"
    done < "$custom_values"
}

# Sync a single module config
sync_module_config() {
    local module_name="$1"
    local dist_source="$2"
    local conf_target="$3"
    
    log_info "Syncing $module_name..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing config
    if [[ -f "$conf_target" ]]; then
        cp "$conf_target" "$BACKUP_DIR/$(basename "$conf_target").old"
    fi
    
    # Extract custom values
    local custom_values="/tmp/custom_values_${module_name}.txt"
    extract_custom_values "$conf_target" "$dist_source" > "$custom_values"
    
    local custom_count=$(wc -l < "$custom_values" 2>/dev/null || echo 0)
    
    # Copy new dist file
    cp "$dist_source" "${conf_target}.dist"
    
    # Apply customizations
    local new_conf="/tmp/new_conf_${module_name}.conf"
    apply_custom_values "$dist_source" "$custom_values" "$new_conf"
    
    # Generate diff report
    if [[ -f "$conf_target" ]]; then
        diff -u "$conf_target" "$new_conf" > "$BACKUP_DIR/${module_name}_changes.diff" 2>&1 || true
    fi
    
    # Move new config into place
    mv "$new_conf" "$conf_target"
    rm -f "$custom_values"
    
    if [[ $custom_count -gt 0 ]]; then
        log_success "$module_name: Updated with $custom_count custom settings preserved"
    else
        log_success "$module_name: Updated (using defaults)"
    fi
}

# Main
main() {
    log_info "Starting module configuration sync..."
    log_info "Project root: $PROJECT_ROOT"
    echo ""
    
    mkdir -p "$CONF_DIR"
    
    local count=0
    for dist_file in "$MODULES_DIR"/*/conf/*.conf.dist; do
        [[ ! -f "$dist_file" ]] && continue
        
        local module_name=$(basename $(dirname $(dirname "$dist_file")))
        local conf_name=$(basename "$dist_file" .dist)
        local conf_target="$CONF_DIR/${conf_name}"
        
        sync_module_config "$module_name" "$dist_file" "$conf_target"
        ((count++))
    done
    
    echo ""
    log_success "Configuration sync complete!"
    log_info "Processed $count module configurations"
    log_info "Backups saved to: $BACKUP_DIR"
    echo ""
    log_warning "Review changes: ls -la $BACKUP_DIR/"
    log_warning "Restart worldserver to apply: docker compose restart ac-worldserver"
}

main "$@"
