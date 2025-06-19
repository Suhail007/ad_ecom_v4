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
APP_URL="http://localhost"
HEALTH_CHECK_ENDPOINT="$APP_URL/health"
LOG_FILE="/var/log/laravel-monitor.log"
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_FILES=5

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Function to log messages
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to check if a service is running
is_service_running() {
    if pgrep -f "$1" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$usage" -gt 90 ]; then
        log "${RED}WARNING: Disk space is critically low! $usage% used.${NC}"
        return 1
    elif [ "$usage" -gt 75 ]; then
        log "${YELLOW}WARNING: Disk space is getting low. $usage% used.${NC}"
        return 0
    else
        log "${GREEN}Disk space is OK. $usage% used.${NC}"
        return 0
    fi
}

# Function to check memory usage
check_memory() {
    local total_mem
    local used_mem
    local free_mem
    local used_percentage
    
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    used_mem=$(free -m | awk '/^Mem:/{print $3}')
    free_mem=$(free -m | awk '/^Mem:/{print $4}')
    used_percentage=$((used_mem * 100 / total_mem))
    
    if [ "$used_percentage" -gt 90 ]; then
        log "${RED}WARNING: Memory usage is critically high! ${used_percentage}% used.${NC}"
        return 1
    elif [ "$used_percentage" -gt 75 ]; then
        log "${YELLOW}WARNING: Memory usage is high. ${used_percentage}% used.${NC}"
        return 0
    else
        log "${GREEN}Memory usage is OK. ${used_percentage}% used.${NC}"
        return 0
    fi
}

# Function to check CPU load
check_cpu_load() {
    local load
    local cores
    
    load=$(cat /proc/loadavg | awk '{print $1}')
    cores=$(nproc)
    
    # Compare load to number of cores
    if (( $(echo "$load > $cores * 0.9" | bc -l) )); then
        log "${RED}WARNING: CPU load is very high! Load average: $load${NC}"
        return 1
    elif (( $(echo "$load > $cores * 0.7" | bc -l) )); then
        log "${YELLOW}WARNING: CPU load is high. Load average: $load${NC}"
        return 0
    else
        log "${GREEN}CPU load is normal. Load average: $load${NC}"
        return 0
    fi
}

# Function to check application health
check_application_health() {
    if ! command -v curl &> /dev/null; then
        log "${RED}ERROR: curl is not installed. Cannot check application health.${NC}"
        return 1
    fi
    
    local response
    local status
    
    if ! response=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_ENDPOINT"); then
        log "${RED}ERROR: Failed to connect to $HEALTH_CHECK_ENDPOINT${NC}"
        return 1
    fi
    
    if [ "$response" = "200" ]; then
        log "${GREEN}Application is healthy. Status code: $response${NC}"
        return 0
    else
        log "${RED}ERROR: Application health check failed. Status code: $response${NC}"
        return 1
    fi
}

# Function to check if services are running
check_services() {
    local services=("php-fpm" "nginx" "redis-server" "supervisord")
    local all_ok=true
    
    for service in "${services[@]}"; do
        if is_service_running "$service"; then
            log "${GREEN}✓ $service is running${NC}"
        else
            log "${RED}✗ $service is NOT running${NC}"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    return 0
}

# Function to rotate log file if it's too large
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local size
        size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
        
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            log "Rotating log file..."
            
            # Keep only the last MAX_LOG_FILES log files
            for i in $(seq $((MAX_LOG_FILES - 1)) -1 1); do
                if [ -f "${LOG_FILE}.${i}" ]; then
                    mv -f "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
                fi
            done
            
            # Rotate current log
            mv "$LOG_FILE" "${LOG_FILE}.1"
            touch "$LOG_FILE"
        fi
    fi
}

# Main function
main() {
    log "${BLUE}=== Starting $APP_NAME Monitoring ===${NC}"
    
    # Check system resources
    check_disk_space
    check_memory
    check_cpu_load
    
    # Check services
    check_services
    
    # Check application health
    if check_application_health; then
        log "${GREEN}✓ Application is healthy${NC}"
    else
        log "${RED}✗ Application health check failed${NC}"
    fi
    
    # Rotate logs if needed
    rotate_logs
    
    log "${BLUE}=== Monitoring completed ===${NC}"
}

# Run main function
main

exit 0
