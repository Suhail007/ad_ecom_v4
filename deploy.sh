#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
FORCE=false
MIGRATE=false
SEED=false
CLEAR_CACHE=false
OPTIMIZE=false

# Function to display usage
function show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force deployment without confirmation"
    echo "  -m, --migrate       Run database migrations"
    echo "  -s, --seed          Seed the database"
    echo "  -c, --clear-cache   Clear all caches"
    echo "  -o, --optimize      Run optimization commands"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_usage
            ;;
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
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
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
echo -e "${YELLOW}Installing Composer dependencies...${NC}"
run_command composer install --optimize-autoloader --no-dev --prefer-dist --no-interaction

# Install NPM dependencies and build assets
echo -e "${YELLOW}Installing NPM dependencies...${NC}"
run_command npm ci --no-audit --prefer-offline

echo -e "${YELLOW}Building assets...${NC}"
run_command npm run prod

# Run migrations if requested
if [ "$MIGRATE" = true ]; then
    echo -e "${YELLOW}Running migrations...${NC}"
    run_command php artisan migrate --force
    
    # Clear and cache routes/config if we migrated
    run_command php artisan config:cache
    run_command php artisan route:cache
fi

# Run seeders if requested
if [ "$SEED" = true ]; then
    echo -e "${YELLOW}Seeding database...${NC}"
    run_command php artisan db:seed --force
fi

# Clear caches if requested
if [ "$CLEAR_CACHE" = true ] || [ "$MIGRATE" = true ]; then
    echo -e "${YELLOW}Clearing caches...${NC}"
    run_command php artisan cache:clear
    run_command php artisan config:clear
    run_command php artisan route:clear
    run_command php artisan view:clear
    run_command php artisan event:clear
    
    # Clear all Redis databases if available
    if command -v redis-cli &> /dev/null; then
        echo -e "${YELLOW}Flushing Redis cache...${NC}"
        redis-cli flushall
    fi
fi

# Run optimization command
if [ "$OPTIMIZE" = true ]; then
    echo -e "${YELLOW}Running application optimization...${NC}"
    if php artisan list | grep -q "app:optimize"; then
        run_command php artisan app:optimize
    else
        echo -e "${YELLOW}Custom optimize command not found, running standard optimization...${NC}"
        run_command php artisan optimize
        run_command php artisan config:cache
        run_command php artisan route:cache
        run_command php artisan view:cache
        run_command php artisan event:cache
    fi
else
    # Standard optimization
    echo -e "${YELLOW}Optimizing the application...${NC}"
    run_command php artisan optimize
    run_command php artisan config:cache
    run_command php artisan route:cache
    run_command php artisan view:cache
    run_command php artisan event:cache
fi

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
run_command chmod -R 775 storage bootstrap/cache
run_command chown -R www-data:www-data storage bootstrap/cache

# Restart services
echo -e "${YELLOW}Restarting services...${NC}"
run_command php artisan queue:restart

# Run database optimizations
echo -e "${YELLOW}Optimizing database...${NC}"
if php artisan list | grep -q "db:optimize"; then
    run_command php artisan db:optimize
fi

# Check if the application is running
echo -e "${YELLOW}Verifying application status...${NC}"
if curl -s --head --request GET http://localhost | grep -E "200|301|302" > /dev/null; then
    echo -e "${GREEN}Application is running successfully!${NC}"
else
    echo -e "${YELLOW}Application is not running or not accessible on localhost.${NC}"
    echo -e "${YELLOW}If you're deploying to a remote server, this is expected.${NC}"
fi

# Display deployment information
echo -e "\n${GREEN}Deployment Summary:${NC}"
echo -e "- Environment: ${YELLOW}$(php artisan env)${NC}"
echo -e "- PHP Version: ${YELLOW}$(php -v | head -n 1)${NC}"
echo -e "- Composer Version: ${YELLOW}$(composer --version)${NC}"
echo -e "- Node Version: ${YELLOW}$(node -v)${NC}"

if [ "$MIGRATE" = true ]; then
    echo -e "- ${GREEN}Database migrations were run${NC}"
fi

if [ "$SEED" = true ]; then
    echo -e "- ${GREEN}Database was seeded${NC}"
fi

if [ "$CLEAR_CACHE" = true ]; then
    echo -e "- ${GREEN}Caches were cleared${NC}"
fi

if [ "$OPTIMIZE" = true ]; then
    echo -e "- ${GREEN}Application was optimized${NC}"
fi

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "- Check the application logs: ${YELLOW}tail -f storage/logs/laravel.log${NC}"
echo -e "- Monitor queue workers: ${YELLOW}php artisan queue:work --tries=3 --timeout=120${NC}"

# Check application health if APP_URL is set
if [ -n "$APP_URL" ]; then
    echo -e "\n${GREEN}Checking application health...${NC}"
    if command -v jq &> /dev/null; then
        curl -s $APP_URL/health | jq . 2>/dev/null || echo -e "${YELLOW}Could not check application health. Make sure the application is running.${NC}"
    else
        echo -e "${YELLOW}jq is not installed. Install jq to view health check output as JSON.${NC}"
        curl -s -o /dev/null -w "Status: %{http_code}\n" $APP_URL/health
    fi
fi

# Exit with success
exit 0
