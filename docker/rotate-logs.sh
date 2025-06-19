#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script must be run as root${NC}" >&2
    exit 1
fi

# Configuration
LOG_DIR="/var/log/php8.2-fpm"
NGINX_LOG_DIR="/var/log/nginx"
SUPERVISOR_LOG_DIR="/var/log/supervisor"
APP_LOG_DIR="/var/www/html/storage/logs"

# Create log directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$NGINX_LOG_DIR"
mkdir -p "$SUPERVISOR_LOG_DIR"
mkdir -p "$APP_LOG_DIR"

# Set proper permissions
chown -R www-data:www-data "$LOG_DIR"
chown -R www-data:www-data "$NGINX_LOG_DIR"
chown -R root:adm "$SUPERVISOR_LOG_DIR"
chown -R www-data:www-data "$APP_LOG_DIR"

# Create log files if they don't exist
touch "$LOG_DIR/php8.2-fpm.log"
touch "$NGINX_LOG_DIR/access.log"
touch "$NGINX_LOG_DIR/error.log"
touch "$SUPERVISOR_LOG_DIR/supervisord.log"
touch "$APP_LOG_DIR/laravel.log"

# Set proper permissions for log files
chmod 644 "$LOG_DIR/php8.2-fpm.log"
chmod 644 "$NGINX_LOG_DIR/access.log"
chmod 644 "$NGINX_LOG_DIR/error.log"
chmod 644 "$SUPERVISOR_LOG_DIR/supervisord.log"
chmod 644 "$APP_LOG_DIR/laravel.log"

# Install logrotate if not installed
if ! command -v logrotate &> /dev/null; then
    echo -e "${YELLOW}Installing logrotate...${NC}"
    apt-get update
    apt-get install -y logrotate
fi

# Copy logrotate configuration
cp /var/www/html/docker/logrotate.conf /etc/logrotate.d/laravel

# Test logrotate configuration
echo -e "${GREEN}Testing logrotate configuration...${NC}"
logrotate -d /etc/logrotate.d/laravel

# Create a daily cron job for log rotation
CRON_JOB="0 0 * * * /usr/sbin/logrotate -f /etc/logrotate.d/laravel"
(crontab -l 2>/dev/null | grep -v "/etc/logrotate.d/laravel"; echo "$CRON_JOB") | crontab -

echo -e "${GREEN}Log rotation has been set up successfully!${NC}"
echo -e "Log files location:"
echo -e "- PHP-FPM: $LOG_DIR/php8.2-fpm.log"
echo -e "- Nginx Access: $NGINX_LOG_DIR/access.log"
echo -e "- Nginx Error: $NGINX_LOG_DIR/error.log"
echo -e "- Supervisor: $SUPERVISOR_LOG_DIR/supervisord.log"
echo -e "- Application: $APP_LOG_DIR/laravel.log"

# Restart services to apply changes
systemctl restart rsyslog
systemctl restart cron

echo -e "${GREEN}Log rotation setup completed!${NC}"
