#!/bin/bash
set -e

# Function to check if the database is ready
db_ready() {
    php artisan db:wait
}

# Function to run migrations and seed the database
run_migrations() {
    if [ -f /var/www/html/.env ]; then
        php artisan migrate --force
        php artisan db:seed --force
    fi
}

# Function to clear caches
clear_caches() {
    php artisan cache:clear
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
}

# Function to optimize the application
optimize_app() {
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    php artisan event:cache
}

# Main execution
if [ "$1" = 'supervisord' ] || [ "$1" = 'php-fpm' ]; then
    # Wait for database to be ready
    echo "Waiting for database to be ready..."
    until db_ready; do
        echo "Database is not ready yet. Waiting..."
        sleep 2
    done

    # Run migrations
    echo "Running migrations..."
    run_migrations

    # Clear caches
    echo "Clearing caches..."
    clear_caches

    # Optimize application
    echo "Optimizing application..."
    optimize_app

    # Set permissions
    echo "Setting permissions..."
    chown -R www-data:www-data /var/www/html/storage
    chown -R www-data:www-data /var/www/html/bootstrap/cache
    chmod -R 775 /var/www/html/storage
    chmod -R 775 /var/www/html/bootstrap/cache

    # Create storage link if it doesn't exist
    if [ ! -L /var/www/html/public/storage ]; then
        php artisan storage:link
    fi

    # Clear and optimize caches again
    echo "Final optimization..."
    php artisan optimize:clear
    php artisan optimize
fi

exec "$@"
