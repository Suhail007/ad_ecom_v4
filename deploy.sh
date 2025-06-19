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

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found. Using default values.${NC}"
fi

# Default values
APP_NAME=${APP_NAME:-"laravel-app"}
APP_ENV=${APP_ENV:-"production"}
APP_DEBUG=${APP_DEBUG:-"false"}
APP_URL=${APP_URL:-"http://localhost"}

DB_CONNECTION=${DB_CONNECTION:-"pgsql"}
DB_HOST=${DB_HOST:-"127.0.0.1"}
DB_PORT=${DB_PORT:-"5432"}
DB_DATABASE=${DB_DATABASE:-"laravel"}
DB_USERNAME=${DB_USERNAME:-"postgres"}
DB_PASSWORD=${DB_PASSWORD:-""}

REDIS_HOST=${REDIS_HOST:-"127.0.0.1"}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
REDIS_PORT=${REDIS_PORT:-"6379"}

# Function to display usage
function show_usage() {
FORCE=false
MIGRATE=false
SEED=false
CLEAR_CACHE=false
OPTIMIZE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -f|--force)
            FORCE=true
            shift
            ;;
        -m|--migrate)
            MIGRATE=true
            shift
            ;;
        -s|--seed)
            SEED=true
            shift
            ;;
        -c|--clear-cache)
            CLEAR_CACHE=true
            shift
            ;;
        -o|--optimize)
            OPTIMIZE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to run a command with error handling
run_command() {
    echo -e "${YELLOW}Running: $@${NC}"
    if ! $@; then
        echo -e "${RED}Error: Command failed: $@${NC}" >&2
        exit 1
    fi
}

echo -e "${YELLOW}Starting deployment...${NC}"

# Check if the working directory is clean
if [ "$FORCE" = false ]; then
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}Working directory is not clean. Use --force to deploy anyway.${NC}"
        exit 1
    fi
fi

# Pull the latest changes
run_command git pull

# Install Composer dependencies
echo -e "${YELLOW}Installing Composer dependencies...${NC}
run_command composer install --optimize-autoloader --no-dev --prefer-dist --no-interaction

# Install NPM dependencies and build assets
echo -e "${YELLOW}Installing NPM dependencies...${NC}
run_command npm ci --no-audit --prefer-offline

echo -e "${YELLOW}Building assets...${NC}
run_command npm run prod

# Run migrations if requested
sed -i "s/DB_PORT=.*/DB_PORT=$DB_PORT/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD='$DB_PASSWORD'/" .env

# Set Redis configuration
sed -i "s/REDIS_HOST=.*/REDIS_HOST=$REDIS_HOST/" .env
sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD='$REDIS_PASSWORD'/" .env
sed -i "s/REDIS_PORT=.*/REDIS_PORT=$REDIS_PORT/" .env

# Run database migrations if requested
if [ "$MIGRATE" = true ]; then
    echo -e "${GREEN}Running database migrations...${NC}"
    php artisan migrate --force
    
    # Seed the database if requested
    if [ "$SEED" = true ]; then
        echo -e "${GREEN}Seeding the database...${NC}"
        php artisan db:seed --force
    fi
fi

# Clear and cache configuration if requested
if [ "$CACHE" = true ]; then
    echo -e "${GREEN}Caching configuration...${NC}"
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    php artisan event:cache
else
    echo -e "${YELLOW}Skipping configuration caching.${NC}"
fi

# Set proper permissions
echo -e "${GREEN}Setting permissions...${NC}"
chown -R www-data:www-data .
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
chmod -R 777 storage bootstrap/cache

# Restart services
echo -e "${GREEN}Restarting services...${NC}"
systemctl restart php8.2-fpm
systemctl restart nginx

# Clear application cache
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Optimize application
php artisan optimize

# Display completion message
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "Application URL: ${YELLOW}$APP_URL${NC}"

# Check application health
echo -e "${GREEN}Checking application health...${NC}"
curl -s $APP_URL/health | jq . || echo -e "${YELLOW}Could not check application health. Make sure the application is running.${NC}"

exit 0
