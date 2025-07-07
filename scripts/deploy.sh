#!/bin/bash

# Advent Hymnals Deployment Script
# This script handles the deployment of the Advent Hymnals application

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="ghcr.io/adventhymnals/advent-hymnals-web"
CONTAINER_NAME="advent-hymnals-web"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    log_success "Requirements check passed"
}

create_external_network() {
    log_info "Ensuring external Docker network exists..."
    
    if docker network ls | grep -q web-network; then
        log_info "External network 'web-network' already exists"
    else
        docker network create web-network
        log_success "Created external network 'web-network'"
    fi
}

check_environment() {
    log_info "Checking environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warning "Environment file $ENV_FILE not found. Copying from example..."
        if [[ -f ".env.example" ]]; then
            cp .env.example "$ENV_FILE"
            log_warning "Please edit $ENV_FILE with your configuration before continuing."
            exit 1
        else
            log_error "No environment example file found."
            exit 1
        fi
    fi
    
    # Check required environment variables
    source "$ENV_FILE"
    
    if [[ -z "${SITE_URL:-}" ]]; then
        log_error "SITE_URL is not set in $ENV_FILE"
        exit 1
    fi
    
    log_success "Environment configuration check passed"
}

pull_latest_image() {
    log_info "Pulling latest image from $REPO_URL..."
    
    if docker pull "$REPO_URL:latest"; then
        log_success "Successfully pulled latest image"
    else
        log_error "Failed to pull latest image"
        exit 1
    fi
}

backup_data() {
    log_info "Creating backup of existing data..."
    
    BACKUP_DIR="./backups"
    BACKUP_FILE="backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    if docker volume ls | grep -q hymnal-data; then
        docker run --rm \
            -v advent-hymnals-web_hymnal-data:/source \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine tar czf "/backup/$BACKUP_FILE" -C /source . 2>/dev/null || true
        
        if [[ -f "$BACKUP_DIR/$BACKUP_FILE" ]]; then
            log_success "Backup created: $BACKUP_DIR/$BACKUP_FILE"
        else
            log_warning "No existing data found to backup"
        fi
    else
        log_warning "No existing data volume found"
    fi
}

deploy() {
    log_info "Deploying Advent Hymnals..."
    
    # Ensure external network exists
    create_external_network
    
    # Stop existing containers
    if docker compose ps -q | grep -q .; then
        log_info "Stopping existing containers..."
        docker compose down
    fi
    
    # Start new containers
    log_info "Starting new containers..."
    if docker compose up -d; then
        log_success "Deployment completed successfully"
    else
        log_error "Deployment failed"
        exit 1
    fi
    
    # Wait for health check
    log_info "Waiting for application to be healthy..."
    sleep 10
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf "http://localhost/api/health" > /dev/null 2>&1; then
            log_success "Application is healthy and ready"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Application failed to become healthy after $max_attempts attempts"
            log_info "Checking container logs..."
            docker compose logs --tail=20 "$CONTAINER_NAME"
            exit 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for health check..."
        sleep 5
        ((attempt++))
    done
}

cleanup() {
    log_info "Cleaning up old images..."
    
    # Remove old images (keep last 3 versions)
    docker images "$REPO_URL" --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" | \
        tail -n +2 | sort -k3 -r | tail -n +4 | awk '{print $2}' | \
        xargs -r docker rmi 2>/dev/null || true
    
    # Clean up unused volumes and networks
    docker volume prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    
    log_success "Cleanup completed"
}

show_status() {
    log_info "Deployment Status:"
    echo
    
    # Container status
    echo "Container Status:"
    docker compose ps
    echo
    
    # Health check
    echo "Health Check:"
    if curl -sf "http://localhost/api/health" | jq . 2>/dev/null; then
        log_success "Application is healthy"
    else
        log_warning "Health check failed or JSON parsing unavailable"
        curl -sf "http://localhost/api/health" || log_error "Health endpoint not accessible"
    fi
    echo
    
    # Resource usage
    echo "Resource Usage:"
    docker stats "$CONTAINER_NAME" --no-stream 2>/dev/null || log_warning "Could not get container stats"
    echo
    
    # Recent logs
    echo "Recent Logs (last 10 lines):"
    docker compose logs --tail=10 "$CONTAINER_NAME"
}

# Main execution
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        "deploy"|"")
            log_info "Starting Advent Hymnals deployment..."
            check_requirements
            create_external_network
            check_environment
            backup_data
            pull_latest_image
            deploy
            cleanup
            show_status
            log_success "Deployment completed successfully!"
            ;;
        "status")
            show_status
            ;;
        "logs")
            docker compose logs -f "$CONTAINER_NAME"
            ;;
        "stop")
            log_info "Stopping Advent Hymnals..."
            docker compose down
            log_success "Stopped successfully"
            ;;
        "restart")
            log_info "Restarting Advent Hymnals..."
            docker compose restart
            log_success "Restarted successfully"
            ;;
        "update")
            log_info "Updating Advent Hymnals..."
            pull_latest_image
            docker compose up -d
            log_success "Update completed"
            ;;
        "backup")
            backup_data
            ;;
        "ssl")
            log_info "Setting up SSL certificates..."
            if [[ -f "./scripts/setup-ssl.sh" ]]; then
                ./scripts/setup-ssl.sh
            else
                log_error "SSL setup script not found at ./scripts/setup-ssl.sh"
                exit 1
            fi
            ;;
        "network")
            create_external_network
            ;;
        "help")
            echo "Advent Hymnals Deployment Script"
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  deploy  (default) - Full deployment with backup"
            echo "  status            - Show current status"
            echo "  logs              - Follow container logs"
            echo "  stop              - Stop all containers"
            echo "  restart           - Restart containers"
            echo "  update            - Pull latest image and restart"
            echo "  backup            - Create data backup"
            echo "  ssl               - Set up SSL certificates with Let's Encrypt"
            echo "  network           - Create external Docker network"
            echo "  help              - Show this help message"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"