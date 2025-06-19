#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Laravel App"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/${APP_NAME// /_}"
LOG_FILE="$BACKUP_DIR/backup_$TIMESTAMP.log"
KEEP_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log messages
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Load environment variables
if [ -f /var/www/html/.env ]; then
    export $(grep -v '^#' /var/www/html/.env | xargs)
else
    log "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Check required commands
for cmd in mysqldump pg_dump tar gzip; do
    if ! command_exists "$cmd"; then
        log "${RED}ERROR: $cmd is not installed${NC}"
        exit 1
    fi
done

# Function to create database backup
db_backup() {
    local db_type="$1"
    local backup_file="$BACKUP_DIR/${db_type}_backup_$TIMESTAMP.sql"
    
    log "${BLUE}Creating $db_type database backup...${NC}"
    
    case $db_type in
        mysql)
            if ! command_exists mysqldump; then
                log "${YELLOW}WARNING: mysqldump not found, skipping MySQL backup${NC}"
                return 1
            fi
            
            mysqldump \
                --host="$DB_HOST" \
                --port="${DB_PORT:-3306}" \
                --user="$DB_USERNAME" \
                --password="$DB_PASSWORD" \
                "$DB_DATABASE" > "$backup_file" 2>> "$LOG_FILE"
            ;;
            
        pgsql)
            if ! command_exists pg_dump; then
                log "${YELLOW}WARNING: pg_dump not found, skipping PostgreSQL backup${NC}"
                return 1
            fi
            
            PGPASSWORD="$DB_PASSWORD" pg_dump \
                --host="$DB_HOST" \
                --port="${DB_PORT:-5432}" \
                --username="$DB_USERNAME" \
                --dbname="$DB_DATABASE" \
                --no-password \
                --format=custom \
                --file="$backup_file" 2>> "$LOG_FILE"
            ;;
            
        *)
            log "${YELLOW}WARNING: Unsupported database type: $db_type${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ] && [ -f "$backup_file" ]; then
        log "${GREEN}✓ $db_type backup created: $backup_file${NC}"
        echo "$backup_file"
        return 0
    else
        log "${RED}✗ Failed to create $db_type backup${NC}"
        return 1
    fi
}

# Function to create files backup
files_backup() {
    local src_dir="/var/www/html"
    local exclude_file="/tmp/backup_exclude.txt"
    local backup_file="$BACKUP_DIR/files_backup_$TIMESTAMP.tar.gz"
    
    # Create exclude file
    cat > "$exclude_file" << EOL
$src_dir/node_modules
$src_dir/vendor
$src_dir/storage/framework/cache
$src_dir/storage/framework/sessions
$src_dir/storage/framework/views
$src_dir/storage/logs
$src_dir/storage/debugbar
$src_dir/.git
$src_dir/.github
$src_dir/.idea
$src_dir/.vscode
$src_dir/.env
$src_dir/.env.*
$src_dir/*.sql
$src_dir/*.sql.gz
$src_dir/*.log
$src_dir/*.tar.gz
$src_dir/*.zip
$src_dir/backup_*
$src_dir/storage/app/backup*
$src_dir/storage/app/public/*
$src_dir/public/storage
$src_dir/bootstrap/cache/*.php
$src_dir/storage/clockwork
EOL
    
    log "${BLUE}Creating files backup...${NC}"
    
    # Create tar archive
    if tar --exclude-from="$exclude_file" -czf "$backup_file" -C "$(dirname "$src_dir")" "$(basename "$src_dir")" 2>> "$LOG_FILE"; then
        log "${GREEN}✓ Files backup created: $backup_file${NC}"
        echo "$backup_file"
        rm -f "$exclude_file"
        return 0
    else
        log "${RED}✗ Failed to create files backup${NC}"
        rm -f "$exclude_file"
        return 1
    fi
}

# Function to clean up old backups
cleanup_old_backups() {
    log "${BLUE}Cleaning up backups older than $KEEP_DAYS days...${NC}"
    
    # Find and delete old backup files
    find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) -mtime +$KEEP_DAYS -exec rm -f {} \;
    
    # Find and delete old log files
    find "$BACKUP_DIR" -type f -name "*.log" -mtime +$KEEP_DAYS -exec rm -f {} \;
    
    log "${GREEN}✓ Cleanup completed${NC}"
}

# Function to upload to S3 (if configured)
upload_to_s3() {
    local file_path="$1"
    
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ] || [ -z "$AWS_BUCKET" ]; then
        log "${YELLOW}S3 credentials not configured, skipping upload${NC}"
        return 1
    fi
    
    if ! command_exists aws; then
        log "${YELLOW}AWS CLI not found, please install it to enable S3 uploads${NC}"
        return 1
    fi
    
    local s3_path="s3://$AWS_BUCKET/backups/$(basename "$file_path")"
    
    log "${BLUE}Uploading $file_path to S3...${NC}"
    
    if aws s3 cp "$file_path" "$s3_path" --region "$AWS_DEFAULT_REGION" >> "$LOG_FILE" 2>&1; then
        log "${GREEN}✓ Successfully uploaded to $s3_path${NC}"
        return 0
    else
        log "${RED}✗ Failed to upload to S3${NC}"
        return 1
    fi
}

# Main function
main() {
    log "${BLUE}=== Starting $APP_NAME Backup ===${NC}"
    
    # Create database backup based on connection type
    case $DB_CONNECTION in
        mysql)
            db_backup "mysql"
            ;;
        pgsql|postgresql)
            db_backup "pgsql"
            ;;
        sqlite|sqlsrv|*)
            log "${YELLOW}Skipping database backup (unsupported type: $DB_CONNECTION)${NC}"
            ;;
    esac
    
    # Create files backup
    files_backup
    
    # Upload to S3 if configured
    if [ -n "$AWS_BUCKET" ]; then
        for file in "$BACKUP_DIR"/*_backup_"$TIMESTAMP".*; do
            if [ -f "$file" ]; then
                upload_to_s3 "$file"
            fi
        done
    fi
    
    # Clean up old backups
    cleanup_old_backups
    
    log "${BLUE}=== Backup completed ===${NC}"
    
    # Display backup size
    du -sh "$BACKUP_DIR"/*_backup_"$TIMESTAMP".* 2>/dev/null | while read -r size file; do
        log "Backup file: $file (${size})"
    done
    
    log "Backup log: $LOG_FILE"
}

# Run main function
main

exit 0
