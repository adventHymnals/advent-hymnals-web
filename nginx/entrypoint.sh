#!/bin/bash
set -e

# Read domains from domains.txt
DOMAINS_FILE="/etc/nginx/domains.txt"
if [ ! -f "$DOMAINS_FILE" ]; then
  echo "Warning: domains.txt file not found at $DOMAINS_FILE. Creating default file."
  echo "adventhymnals.org www.adventhymnals.org" > "$DOMAINS_FILE"
fi

# Read domains
DOMAINS=$(cat "$DOMAINS_FILE")
PRIMARY_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')

# Check if SSL certificates exist
CERT_PATH="/etc/letsencrypt/live/$PRIMARY_DOMAIN/fullchain.pem"
if [ ! -f "$CERT_PATH" ]; then
  echo "SSL certificates not found. Setting up Let's Encrypt certificates..."
  
  # Install certbot if not already installed
  if ! command -v certbot &> /dev/null; then
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
  fi
  
  # Format domain parameters for certbot
  DOMAIN_PARAMS=""
  for domain in $DOMAINS; do
    DOMAIN_PARAMS="$DOMAIN_PARAMS -d $domain"
  done
  
  # Get certificates
  certbot --nginx --agree-tos --non-interactive --email admin@$PRIMARY_DOMAIN $DOMAIN_PARAMS
  
  echo "SSL certificates successfully obtained."
else
  echo "SSL certificates already exist."
fi

# Generate nginx configuration for each domain
echo "Generating NGINX configuration for all domains..."

mkdir -p /etc/nginx/templates

# Main configuration template
cat > /etc/nginx/templates/default.conf.template << EOF
# Default server configuration
# server {
#     listen 80 default_server;
#     listen [::]:80 default_server;
#     server_name _;
    
#     location / {
#         return 301 https://\$host\$request_uri;
#     }
# }

# Redirect www to non-www
server {
    listen 443 ssl;
    server_name www.${NGINX_HOST};
    
    ssl_certificate /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem;
    
    return 301 https://${NGINX_HOST}\$request_uri;
}

# Main application server
server {
    listen 443 ssl;
    server_name ${NGINX_HOST};
    
    ssl_certificate /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem;
    
    location / {
        proxy_pass http://advent-hymnals-web:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "NGINX configuration generated successfully."