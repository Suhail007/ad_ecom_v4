# Laravel Application Deployment Guide

This document provides detailed instructions for deploying the Laravel application to a production environment, specifically optimized for Railway.com.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Deployment Steps](#deployment-steps)
4. [Configuration](#configuration)
5. [Maintenance](#maintenance)
6. [Troubleshooting](#troubleshooting)
7. [Monitoring](#monitoring)
8. [Backup and Restore](#backup-and-restore)
9. [Scaling](#scaling)
10. [Security](#security)

## Prerequisites

Before deploying, ensure you have the following:

- [Docker](https://www.docker.com/) installed on your local machine
- [Railway CLI](https://docs.railway.app/develop/cli) installed (optional)
- [Git](https://git-scm.com/) for version control
- [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/) for frontend assets
- [Composer](https://getcomposer.org/) for PHP dependencies

## Environment Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. **Install PHP dependencies**:
   ```bash
   composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
   ```

3. **Install Node.js dependencies and build assets**:
   ```bash
   npm install --production
   npm run production
   ```

4. **Copy the environment file**:
   ```bash
   cp .env.example .env
   php artisan key:generate
   ```

5. **Update the environment variables** in the `.env` file according to your production settings.

## Deployment Steps

### Local Development

1. **Start the development server**:
   ```bash
   php artisan serve
   ```

2. **Access the application** at `http://localhost:8000`

### Production Deployment to Railway

1. **Login to Railway**:
   ```bash
   railway login
   ```

2. **Link your project** (if not already linked):
   ```bash
   railway link
   ```

3. **Deploy your application**:
   ```bash
   railway up
   ```

4. **Set up environment variables** in the Railway dashboard or using the CLI:
   ```bash
   railway vars set KEY=VALUE
   ```

5. **Run migrations**:
   ```bash
   railway run php artisan migrate --force
   ```

6. **Seed the database** (if needed):
   ```bash
   railway run php artisan db:seed --force
   ```

## Configuration

### Environment Variables

Key environment variables that need to be configured:

```ini
# Application
APP_NAME="Laravel"
APP_ENV=production
APP_DEBUG=false
APP_KEY=
APP_URL=https://your-railway-app.railway.app

# Database
DB_CONNECTION=pgsql
DB_HOST=
DB_PORT=5432
DB_DATABASE=
DB_USERNAME=
DB_PASSWORD=

# Redis
REDIS_HOST=
REDIS_PASSWORD=
REDIS_PORT=6379

# Session
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# Cache
CACHE_DRIVER=redis

# Queue
QUEUE_CONNECTION=redis

# Mail
MAIL_MAILER=smtp
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
```

### Nginx Configuration

The application includes an optimized Nginx configuration in `docker/nginx.conf`. Key optimizations include:

- Gzip compression
- Static file caching
- Security headers
- Rate limiting
- HTTP/2 support

### PHP-FPM Configuration

Optimized PHP-FPM configuration in `docker/php-fpm.conf` includes:

- Dynamic process management
- Optimized request handling
- Performance tuning

## Maintenance

### Clearing Caches

```bash
# Clear application cache
php artisan cache:clear

# Clear configuration cache
php artisan config:clear

# Clear route cache
php artisan route:clear

# Clear view cache
php artisan view:clear

# Clear compiled view files
php artisan view:cache

# Clear all caches
php artisan optimize:clear
```

### Maintenance Mode

```bash
# Enable maintenance mode
php artisan down

# Disable maintenance mode
php artisan up

# Maintenance mode with secret
php artisan down --secret="maintenance-secret"
```

## Monitoring

The application includes several monitoring endpoints:

- `GET /health` - Application health check
- `GET /telescope` - Laravel Telescope (if enabled)
- `GET /horizon` - Laravel Horizon dashboard (if enabled)

### Logs

View application logs:

```bash
# View Laravel logs
tail -f storage/logs/laravel.log

# View PHP-FPM logs
tail -f /var/log/php8.2-fpm.log

# View Nginx access logs
tail -f /var/log/nginx/access.log

# View Nginx error logs
tail -f /var/log/nginx/error.log
```

## Backup and Restore

### Creating Backups

Use the included backup script to create database and file backups:

```bash
./backup.sh
```

Options:
- `--db` - Backup database only
- `--files` - Backup files only
- `--upload` - Upload to S3 after backup

### Restoring from Backup

1. **Database**:
   ```bash
   # For MySQL
   mysql -u username -p database_name < backup.sql

   # For PostgreSQL
   pg_restore -U username -d database_name backup.dump
   ```

2. **Files**:
   ```bash
   tar -xzvf backup.tar.gz -C /path/to/restore
   ```

## Scaling

### Horizontal Scaling

To scale your application on Railway:

```bash
# Scale web service to 2 instances
railway scale web=2

# Scale queue worker to 3 instances
railway scale queue=3

# Scale scheduler to 1 instance
railway scale scheduler=1
```

### Vertical Scaling

Adjust the resources in your `railway.toml` file:

```toml
[build]
  builder = "nixpacks"
  buildCommand = "./build.sh"

[deploy]
  startCommand = "./start.sh"
  healthcheckPath = "/health"
  healthcheckTimeout = 30

[services.web]
  type = "web"
  numInstances = 2
  cpu = 2
  memory = 1024
  port = 8000

[services.queue]
  type = "worker"
  numInstances = 1
  cpu = 1
  memory = 512

[services.scheduler]
  type = "worker"
  numInstances = 1
  cpu = 0.5
  memory = 256
  schedule = "* * * * *"
  command = "php artisan schedule:run"
```

## Security

### SSL/TLS

Railway automatically provisions SSL certificates for your domain. To enforce HTTPS, set the following environment variable:

```ini
FORCE_HTTPS=true
```

### Security Headers

Security headers are configured in the Nginx configuration. To modify them, edit `docker/nginx.conf`.

### Rate Limiting

Rate limiting is configured in the Nginx configuration. The default rate is 60 requests per minute per IP address.

### Authentication

- Use strong, unique passwords for all accounts
- Enable 2FA for admin accounts
- Regularly rotate API keys and credentials

## Troubleshooting

### Common Issues

1. **Application not starting**
   - Check logs: `railway logs`
   - Verify environment variables
   - Check database connection

2. **Database connection issues**
   - Verify credentials in `.env`
   - Check if the database is running
   - Verify network connectivity

3. **Asset loading issues**
   - Run `npm run production`
   - Check file permissions
   - Verify the `APP_URL` environment variable

4. **Queue workers not processing jobs**
   - Check if Redis is running
   - Verify queue connection in `.env`
   - Check worker logs

### Getting Help

For additional help, please contact the development team or refer to the following resources:

- [Laravel Documentation](https://laravel.com/docs)
- [Railway Documentation](https://docs.railway.app/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PHP Documentation](https://www.php.net/docs.php)

## License

This project is open-source and available under the [MIT License](LICENSE).
