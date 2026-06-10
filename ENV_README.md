# AzerothCore Environment Configuration

This project uses environment variables and templates to manage configuration across different environments (production and testing). This follows the [12-factor app methodology](https://12factor.net/config).

## Quick Start

### First Time Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   # Or symlink to a specific environment
   ln -s .env.testing .env  # For testing
   ln -s .env.production .env  # For production
   ```

2. Generate configuration files:
   ```bash
   make generate
   ```

3. Start the containers:
   ```bash
   make up
   ```

### Daily Operations

```bash
# Check status
make status

# View logs
make logs
make logs CONTAINER=testing-ac-worldserver

# Restart containers
make restart

# Stop containers
make down

# Backup databases (production only)
make backup

# Restore from production backups (testing only)
make restore
```

## Environment Files

- **`.env.example`** - Template with all available variables (committed to git)
- **`.env.production`** - Production-specific values
- **`.env.testing`** - Testing-specific values
- **`.env`** - Active environment (symlink, **NOT** committed to git)

## Key Differences Between Environments

| Variable | Production | Testing |
|----------|-----------|---------|
| `ENV_NAME` | production | testing |
| `WORLDSERVER_PORT` | 8585 | 8085 |
| `CONTAINER_PREFIX` | ac | testing-ac |
| `NUMA_NODE` | 1 (odd CPUs) | 0 (even CPUs) |
| `CPUSET_CPUS` | 1,3,5...39 | 0,2,4...38 |
| `ENABLE_DB_BACKUPS` | true | false |
| `ENABLE_DB_RESTORES` | false | true |
| `AUTHSERVER_PROFILE` | default | disabled |

## Backup & Restore

### Production Backups

Production automatically backs up databases when `ENABLE_DB_BACKUPS=true`:

```bash
# Manual backup
make backup

# Backups are saved to: /FastStorage/Shared/Azerothcore
# Format: acore_auth-YYYYMMDD_HHMMSS.sql
#         acore_characters-YYYYMMDD_HHMMSS.sql
#         acore_world-YYYYMMDD_HHMMSS.sql

# Old backups (>7 days) are automatically cleaned up
```

**Automated Backups**: Set up a cron job on production:
```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * cd /root/azerothcore-wotlk && make backup >> /var/log/azerothcore-backup.log 2>&1
```

### Testing Restores

Testing restores from production backups when `ENABLE_DB_RESTORES=true`:

```bash
# Restore latest production backups
make restore

# This will:
# 1. Find latest backup for each database
# 2. Drop and recreate testing databases
# 3. Restore from production backups
# 4. Transform data for testing:
#    - Delete old TESTRNDBOT accounts
#    - Rename RNDBOT accounts to TESTRNDBOT
#    - Register all accounts to realm 2
#    - Clean up orphaned characters
```

**Automated Restores**: Set up a cron job on testing:
```bash
# Restore from production every night at 2 AM
0 2 * * * cd /root/azerothcore-wotlk && make restore >> /var/log/azerothcore-restore.log 2>&1
```

## Makefile Commands

```bash
make help       # Show all available commands
make validate   # Validate .env configuration
make generate   # Generate config files from templates
make up         # Generate configs and start containers
make down       # Stop containers
make restart    # Restart containers
make logs       # Show logs (add CONTAINER=name to filter)
make status     # Show container status and resource usage
make backup     # Backup databases (production only)
make restore    # Restore databases (testing only)
make clean      # Remove containers, volumes, and generated configs
```

## Architecture

### Template System

Configuration files are generated from templates using `envsubst`:

1. **Templates** (`.template` files):
   - `docker-compose.override.yml.template`
   - Contains variables like `${WORLDSERVER_PORT}`

2. **Generation Script** (`scripts/generate-configs.sh`):
   - Loads `.env` file
   - Exports all variables
   - Runs `envsubst` on templates
   - Creates final configuration files

3. **Validation Script** (`scripts/validate-env.sh`):
   - Checks for required variables
   - Reports missing or invalid values

### Backup/Restore Scripts

4. **Backup Script** (`scripts/backup-databases.sh`):
   - Only runs if `ENABLE_DB_BACKUPS=true`
   - Uses `${CONTAINER_PREFIX}-database` container
   - Saves to `${BACKUP_DEST_DIR}`
   - Automatically cleans up backups older than 7 days

5. **Restore Script** (`scripts/restore-databases.sh`):
   - Only runs if `ENABLE_DB_RESTORES=true`
   - Uses `${CONTAINER_PREFIX}-database` container
   - Reads from `${BACKUP_SOURCE_HOST}`
   - Applies post-restore transformations for testing

### NUMA Configuration

Both environments use single-NUMA-node strategies to eliminate cross-NUMA memory access:

- **Production (NUMA Node 1)**: CPUs 1,3,5,7,...,39 (20 cores)
- **Testing (NUMA Node 0)**: CPUs 0,2,4,6,...,38 (20 cores)

This improves cache locality and performance for memory-intensive operations.

### Database Strategy

- **Production**:
  - Runs its own authserver
  - Backs up databases to shared storage
  - Database updates enabled (`AC_UPDATES_ENABLE_DATABASES=7`)

- **Testing**:
  - Uses production's authserver (192.168.144.7:3724)
  - Restores databases from production backups
  - Database updates enabled for testing changes
  - Authserver container disabled via profile
  - Bot accounts renamed: RNDBOT → TESTRNDBOT

## Adding New Variables

1. Add to `.env.example` with description
2. Add to environment-specific files (`.env.production`, `.env.testing`)
3. Update template files to use `${VARIABLE_NAME}`
4. Update `scripts/validate-env.sh` if the variable is required
5. Regenerate configs: `make generate`

## Switching Environments

```bash
# Switch to testing
ln -sf .env.testing .env
make restart

# Switch to production
ln -sf .env.production .env
make restart
```

## Important Notes

### Production Safety

- **Monitoring Window**: 4-11 PM EST - NO changes during this time
  - UptimeKuma alerts if production is down
  - Real players: joshr (Bellix) and caitr (Raedyna)

- **Testing is Safe**: No real players, only bots
  - Safe to break, experiment, and test changes
  - Should run 24-48 hours before applying to production

### File Management

- **Committed to Git**:
  - `.env.example`
  - `*.template` files
  - Scripts in `scripts/`
  - `Makefile`
  - This README

- **NOT Committed (in .gitignore)**:
  - `.env`
  - `.env.production`
  - `.env.testing`
  - `docker-compose.override.yml` (generated)
  - Runtime directories (`env/`, `logs/`, etc.)

## Troubleshooting

### Containers won't start

```bash
# Check validation
make validate

# Regenerate configs
make generate

# Check Docker logs
make logs
```

### Wrong environment running

```bash
# Check which .env is active
ls -l .env
cat .env | grep ENV_NAME

# Check container names
docker ps --format '{{.Names}}'
# Should be "ac-*" for production or "testing-ac-*" for testing
```

### Config changes not applied

```bash
# Always regenerate after changing .env
make generate
make restart
```

### Backup/Restore not working

```bash
# Check if enabled in .env
cat .env | grep ENABLE_DB

# Production should have: ENABLE_DB_BACKUPS=true
# Testing should have: ENABLE_DB_RESTORES=true

# Check backup directory exists and is writable
ls -ld /FastStorage/Shared/Azerothcore

# View restore logs
tail -f /FastStorage/Shared/Azerothcore/logs/restore_*.log
```

## Migration Notes

This system replaced the previous branch-based configuration (`main` vs `testing` branches). Benefits:

1. **Single Source of Truth**: One `main` branch for both environments
2. **Easier Maintenance**: Changes apply to both environments by default
3. **Explicit Differences**: Environment-specific config in `.env` files
4. **No Branch Merging**: No need to merge `testing` → `main`
5. **Industry Standard**: 12-factor app methodology widely adopted
6. **Automated Workflows**: Backup/restore scripts use environment variables
