#!/bin/bash
# Make sure this file has executable permissions
# This command runs the queue worker with Redis
php artisan queue:work redis --tries=3 --max-time=3600 