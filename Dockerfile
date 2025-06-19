# Use the official PHP 8.2 FPM image as base
FROM php:8.2-fpm

# Install system dependencies and required PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    curl \
    iputils-ping \
    dnsutils \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libpq-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libgd-dev \
    libmagickwand-dev \
    zip \
    unzip \
    supervisor \
    nginx \
    cron \
    nano \
    htop \
    procps \
    iputils-ping \
    dnsutils \
    jq \
    gnupg2 \
    lsb-release \
    ca-certificates \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql mysqli mbstring exif pcntl bcmath zip intl opcache

# Install Redis extension
RUN pecl install -o -f redis \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis

# Install ImageMagick
RUN pecl install imagick && docker-php-ext-enable imagick

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install AWS CLI (for S3 backups)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip ./aws

# Set timezone
RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo UTC > /etc/timezone

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . /var/www/html/

# Install Composer dependencies (without dev dependencies)
RUN composer install --no-interaction --optimize-autoloader --no-dev

# Install NPM dependencies and build assets
RUN npm install --production \
    && npm run production \
    && npm cache clean --force

# Install Supervisor
RUN mkdir -p /var/log/supervisor

# Copy configuration files
COPY docker/php.ini /usr/local/etc/php/conf.d/php.ini
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/zzz-www.conf
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set up log files
RUN mkdir -p /var/log/nginx /var/log/php /var/log/supervisor \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && touch /var/log/php/error.log /var/log/php/access.log \
    && touch /var/log/supervisor/supervisord.log \
    && chmod -R 777 /var/log/nginx /var/log/php /var/log/supervisor

# Set up application directories
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage \
    && chown -R www-data:www-data /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Set up crontab
RUN (crontab -l ; echo "* * * * * cd /var/www/html && php artisan schedule:run >> /dev/null 2>&1") | crontab -

# Expose ports
EXPOSE 80 443 9000 6001

# Health check (using wget which is more lightweight than curl)
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/api/health || exit 1

# Set working directory
WORKDIR /var/www/html

# Set permissions with better organization and debugging
RUN echo "Setting file permissions..." && \
    mkdir -p /var/www/html/storage/framework/{sessions,views,cache} && \
    mkdir -p /var/www/html/bootstrap/cache && \
    chown -R www-data:www-data /var/www/html && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    find /var/www/html -type f -exec chmod 644 {} \; && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 777 /var/www/html/storage/framework && \
    chmod -R 777 /var/www/html/storage/logs && \
    chmod -R 777 /var/www/html/bootstrap/cache && \
    echo "File permissions set successfully"

# Generate optimized autoload files
RUN composer dump-autoload --optimize

# Create a simple health check script
RUN echo '#!/bin/bash\n\
wget --no-verbose --tries=1 --spider http://localhost/api/health || exit 1' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Create a simple startup script that runs in the foreground
RUN echo '#!/bin/bash\n\
echo "Starting application..."\n\
# Start supervisord in the foreground\nexec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf' > /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 80 9000

# Set the entrypoint to the startup script
CMD ["/start.sh"] 