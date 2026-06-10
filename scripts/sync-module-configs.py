#!/usr/bin/env python3
import os
import re
import sys
import shutil
from pathlib import Path
from datetime import datetime

class ConfigSync:
    def __init__(self, project_root, quiet=False):
        self.project_root = Path(project_root)
        self.modules_dir = self.project_root / 'modules'
        self.conf_dir = self.project_root / 'env' / 'dist' / 'etc' / 'modules'
        self.backup_dir = self.conf_dir / f'.backup-{datetime.now().strftime("%Y%m%d-%H%M%S")}'
        self.quiet = quiet
        self.changes_made = False
        
    def log(self, msg, level='info'):
        if self.quiet and level in ['info', 'success']:
            return
        colors = {
            'info': '\033[0;34m',
            'success': '\033[0;32m',
            'warning': '\033[1;33m',
            'error': '\033[0;31m'
        }
        labels = {
            'info': '[INFO]',
            'success': '[✓]',
            'warning': '[WARNING]',
            'error': '[ERROR]'
        }
        nc = '\033[0m'
        print(f'{colors.get(level, "")}{labels.get(level, "")} {nc}{msg}')
        
    def extract_settings(self, config_file):
        """Extract all key=value settings from a config file"""
        settings = {}
        if not config_file.exists():
            return settings
            
        with open(config_file, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                match = re.match(r'^\s*([^=\s]+)\s*=\s*(.*)$', line)
                if match:
                    key, value = match.groups()
                    settings[key.strip()] = value.strip()
        return settings
    
    def apply_custom_values(self, dist_file, custom_settings, output_file):
        """Apply custom settings to a .conf.dist file"""
        with open(dist_file, 'r', encoding='utf-8', errors='ignore') as f_in:
            lines = f_in.readlines()
        
        modified_lines = []
        for line in lines:
            match = re.match(r'^(\s*)([^=\s]+)(\s*=\s*)(.*)$', line)
            if match:
                indent, key, eq_sign, value = match.groups()
                key = key.strip()
                if key in custom_settings:
                    modified_lines.append(f'{indent}{key}{eq_sign}{custom_settings[key]}\n')
                    continue
            modified_lines.append(line)
        
        with open(output_file, 'w', encoding='utf-8') as f_out:
            f_out.writelines(modified_lines)
    
    def sync_module(self, module_name, dist_source, conf_target):
        """Sync a single module configuration"""
        if not self.quiet:
            self.log(f'Syncing {module_name}...', 'info')
        
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        if conf_target.exists():
            shutil.copy2(conf_target, self.backup_dir / f'{conf_target.name}.old')
        
        dist_settings = self.extract_settings(dist_source)
        conf_settings = self.extract_settings(conf_target)
        
        custom_settings = {}
        for key, value in conf_settings.items():
            if key in dist_settings and value != dist_settings[key]:
                custom_settings[key] = value
        
        dist_target = conf_target.parent / f'{conf_target.stem}.conf.dist'
        
        # Check if .conf.dist changed
        dist_changed = False
        if dist_target.exists():
            import filecmp
            if not filecmp.cmp(dist_source, dist_target, shallow=False):
                dist_changed = True
        else:
            dist_changed = True
        
        # Only update if .conf.dist changed
        if dist_changed:
            self.changes_made = True
            shutil.copy2(dist_source, dist_target)
            
            temp_conf = conf_target.parent / f'.temp_{conf_target.name}'
            self.apply_custom_values(dist_source, custom_settings, temp_conf)
            
            if conf_target.exists():
                diff_file = self.backup_dir / f'{module_name}_changes.diff'
                os.system(f'diff -u "{conf_target}" "{temp_conf}" > "{diff_file}" 2>&1 || true')
            
            shutil.move(str(temp_conf), str(conf_target))
            
            if custom_settings:
                self.log(f'{module_name}: Updated with {len(custom_settings)} custom settings preserved', 'success')
            else:
                self.log(f'{module_name}: Updated (using defaults)', 'success')
        else:
            if not self.quiet:
                self.log(f'{module_name}: No changes needed', 'info')
    
    def sync_all(self):
        """Sync all module configurations"""
        if not self.quiet:
            self.log('Starting module configuration sync...', 'info')
            self.log(f'Project root: {self.project_root}', 'info')
            print()
        
        self.conf_dir.mkdir(parents=True, exist_ok=True)
        
        count = 0
        for dist_file in self.modules_dir.glob('*/conf/*.conf.dist'):
            module_name = dist_file.parent.parent.name
            conf_name = dist_file.stem
            conf_target = self.conf_dir / conf_name
            
            self.sync_module(module_name, dist_file, conf_target)
            count += 1
        
        if self.changes_made:
            print()
            self.log('Configuration sync complete!', 'success')
            self.log(f'Processed {count} module configurations', 'info')
            self.log(f'Backups saved to: {self.backup_dir}', 'info')
            
            if not self.quiet:
                print()
                self.log(f'Review changes: ls -la {self.backup_dir}/', 'warning')
                self.log('Restart worldserver to apply: docker compose restart ac-worldserver', 'warning')
        elif not self.quiet:
            print()
            self.log('All configurations are up to date!', 'success')
            self.log(f'Checked {count} module configurations', 'info')

if __name__ == '__main__':
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Check for --quiet flag
    quiet = '--quiet' in sys.argv or '-q' in sys.argv
    
    syncer = ConfigSync(project_root, quiet=quiet)
    syncer.sync_all()
