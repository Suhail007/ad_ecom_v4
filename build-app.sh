#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Exit on error
set -e

# Log function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    exit 1
}

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    log "Running as root, adjusting file permissions..."
    chown -R www-data:www-data /var/www/html
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache
fi

# Change to the application directory
cd /var/www/html || error "Failed to change to application directory"

log "Starting application build..."

# Install PHP dependencies
log "Installing PHP dependencies..."
composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist || error "Composer install failed"

# Install and build assets
log "Installing Node.js dependencies..."
npm ci --no-audit --prefer-offline || error "npm install failed"

log "Building assets..."
npm run prod || error "Asset build failed"

# Clear all caches
log "Clearing caches..."
php artisan optimize:clear || error "Cache clear failed"

# Cache the application
log "Caching configuration..."
php artisan config:cache || error "Config cache failed"

log "Caching routes..."
php artisan route:cache || error "Route cache failed"

log "Caching views..."
php artisan view:cache || error "View cache failed"

log "Caching events..."
php artisan event:cache || error "Event cache failed"

# Optimize Composer autoloader
log "Optimizing Composer autoloader..."
composer dump-autoload --optimize || error "Composer autoloader optimization failed"

# Set proper permissions
log "Setting file permissions..."
chmod -R 775 storage bootstrap/cache
chmod -R 775 storage/framework/views

# If running as root, change ownership
if [ "$(id -u)" -eq 0 ]; then
    chown -R www-data:www-data /var/www/html
fi

log "${GREEN}Build completed successfully!${NC}"