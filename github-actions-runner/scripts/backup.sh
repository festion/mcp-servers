#!/bin/bash

# GitHub Actions Runner Backup Script
# Backs up runner data, work files, logs, and metrics

set -euo pipefail

# Configuration
BACKUP_DIR="/backup/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="runner_backup_${TIMESTAMP}"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
COMPRESSION=${BACKUP_COMPRESSION:-gzip}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/backup.log"
}

log "Starting backup: $BACKUP_NAME"

# Create temporary directory for backup
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/$BACKUP_NAME"

# Backup runner data
if [ -d "/backup/runner_data" ]; then
    log "Backing up runner data..."
    cp -r "/backup/runner_data" "$TEMP_DIR/$BACKUP_NAME/"
fi

# Backup work directory
if [ -d "/backup/runner_work" ]; then
    log "Backing up work directory..."
    cp -r "/backup/runner_work" "$TEMP_DIR/$BACKUP_NAME/"
fi

# Backup logs
if [ -d "/backup/logs" ]; then
    log "Backing up logs..."
    cp -r "/backup/logs" "$TEMP_DIR/$BACKUP_NAME/"
fi

# Backup metrics data
if [ -d "/backup/metrics_data" ]; then
    log "Backing up metrics data..."
    cp -r "/backup/metrics_data" "$TEMP_DIR/$BACKUP_NAME/"
fi

# Create backup archive
log "Creating backup archive..."
cd "$TEMP_DIR"

if [ "$COMPRESSION" = "gzip" ]; then
    tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
elif [ "$COMPRESSION" = "bzip2" ]; then
    tar -cjf "$BACKUP_DIR/$BACKUP_NAME.tar.bz2" "$BACKUP_NAME"
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.bz2"
else
    tar -cf "$BACKUP_DIR/$BACKUP_NAME.tar" "$BACKUP_NAME"
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar"
fi

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# Clean up old backups
log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "runner_backup_*.tar*" -mtime +$RETENTION_DAYS -delete

# Generate backup manifest
cat > "$BACKUP_DIR/latest_backup.info" << EOF
BACKUP_NAME=$BACKUP_NAME
BACKUP_FILE=$BACKUP_FILE
BACKUP_SIZE=$BACKUP_SIZE
BACKUP_DATE=$(date -Iseconds)
RETENTION_DAYS=$RETENTION_DAYS
COMPRESSION=$COMPRESSION
EOF

log "Backup completed successfully"

# Health check endpoint (if curl is available)
if command -v curl >/dev/null 2>&1; then
    if [ -n "${HEALTH_CHECK_URL:-}" ]; then
        curl -X POST "$HEALTH_CHECK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"service\":\"backup\",\"status\":\"success\",\"backup\":\"$BACKUP_NAME\",\"size\":\"$BACKUP_SIZE\"}" \
            2>/dev/null || true
    fi
fi