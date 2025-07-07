#!/bin/bash

# SSL Setup Script for Advent Hymnals
# Sets up Let's Encrypt SSL certificates using Certbot

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-adventhymnals.org}"
EMAIL="${EMAIL:-admin@adventhymnals.org}"
COMPOSE_FILE="docker-compose.yml"

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
    log_info "Creating external Docker network..."
    
    if docker network ls | grep -q web-network; then
        log_warning "External network 'web-network' already exists"
    else
        docker network create web-network
        log_success "Created external network 'web-network'"
    fi
}

setup_initial_ssl() {
    log_info "Setting up initial SSL certificate for $DOMAIN..."
    
    # Create directories
    mkdir -p ./nginx/ssl
    mkdir -p ./logs/certbot
    
    # Start nginx temporarily for HTTP validation
    log_info "Starting services for certificate validation..."
    docker compose up -d nginx
    
    # Wait for nginx to be ready
    sleep 5
    
    # Request initial certificate
    log_info "Requesting SSL certificate from Let's Encrypt..."
    docker compose run --rm certbot \
        certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        log_success "SSL certificate obtained successfully"
        
        # Restart nginx to load the certificate
        log_info "Restarting nginx with SSL configuration..."
        docker compose restart nginx
        
        log_success "SSL setup completed successfully!"
        log_info "Your site should now be accessible at https://$DOMAIN"
    else
        log_error "Failed to obtain SSL certificate"
        log_warning "Please check your domain DNS settings and try again"
        exit 1
    fi
}

setup_cron_renewal() {
    log_info "Setting up automatic certificate renewal..."
    
    # Start the certbot container for automatic renewals
    docker compose up -d certbot
    
    log_success "Automatic certificate renewal configured"
    log_info "Certificates will be automatically renewed every 12 hours"
}

show_status() {
    log_info "SSL Setup Status:"
    echo
    
    # Check certificate status
    echo "Certificate Status:"
    if docker compose exec -T certbot certbot certificates 2>/dev/null; then
        log_success "Certificates are properly configured"
    else
        log_warning "Could not check certificate status"
    fi
    echo
    
    # Check nginx status
    echo "Nginx Status:"
    docker compose ps nginx
    echo
    
    # Test HTTPS connection
    echo "HTTPS Test:"
    if curl -sf "https://$DOMAIN/api/health" > /dev/null 2>&1; then
        log_success "HTTPS is working correctly"
        echo "✅ Site is accessible at: https://$DOMAIN"
    else
        log_warning "HTTPS test failed"
        echo "❌ Please check nginx logs: docker compose logs nginx"
    fi
}

# Main execution
main() {
    local command="${1:-setup}"
    
    case "$command" in
        "setup"|"")
            log_info "Starting SSL setup for Advent Hymnals..."
            check_requirements
            create_external_network
            setup_initial_ssl
            setup_cron_renewal
            show_status
            log_success "SSL setup completed successfully!"
            ;;
        "renew")
            log_info "Renewing SSL certificates..."
            docker compose exec certbot certbot renew --webroot --webroot-path=/var/www/certbot
            docker compose restart nginx
            log_success "Certificate renewal completed"
            ;;
        "status")
            show_status
            ;;
        "network")
            create_external_network
            ;;
        "help")
            echo "SSL Setup Script for Advent Hymnals"
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  setup   (default) - Full SSL setup with Let's Encrypt"
            echo "  renew             - Manually renew certificates"
            echo "  status            - Show SSL status"
            echo "  network           - Create external Docker network"
            echo "  help              - Show this help message"
            echo
            echo "Environment Variables:"
            echo "  DOMAIN - Domain name (default: adventhymnals.org)"
            echo "  EMAIL  - Email for Let's Encrypt (default: admin@adventhymnals.org)"
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