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

# Check if SSL certificates exist and include all domains
CERT_PATH="/etc/letsencrypt/live/$PRIMARY_DOMAIN/fullchain.pem"
NEED_CERT_UPDATE=false

if [ ! -f "$CERT_PATH" ]; then
  echo "SSL certificates not found. Setting up Let's Encrypt certificates..."
  NEED_CERT_UPDATE=true
else
  echo "SSL certificates found. Checking if all domains are included..."
  
  # Check if certificate includes all domains from domains.txt
  for domain in $DOMAINS; do
    if ! openssl x509 -in "$CERT_PATH" -text -noout | grep -q "DNS:$domain"; then
      echo "Domain $domain not found in certificate. Certificate update needed."
      NEED_CERT_UPDATE=true
      break
    fi
  done
  
  if [ "$NEED_CERT_UPDATE" = false ]; then
    echo "All domains are included in existing certificate."
  fi
fi

if [ "$NEED_CERT_UPDATE" = true ]; then
  echo "Updating SSL certificates to include all domains..."
  
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
  
  # Get/update certificates
  certbot --nginx --agree-tos --non-interactive --email admin@$PRIMARY_DOMAIN $DOMAIN_PARAMS --expand
  
  echo "SSL certificates successfully obtained/updated."
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

EOF

# Generate server blocks for each domain
for domain in $DOMAINS; do
  echo "Generating configuration for domain: $domain"
  
  if [[ "$domain" == "www."* ]]; then
    # WWW redirect block
    cat >> /etc/nginx/templates/default.conf.template << EOF
# Redirect www to non-www
server {
    listen 443 ssl;
    server_name $domain;
    
    ssl_certificate /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem;
    
    return 301 https://${NGINX_HOST}\$request_uri;
}

EOF
  elif [[ "$domain" == "media."* ]]; then
    # Media server block - serve files directly
    cat >> /etc/nginx/templates/default.conf.template << EOF
# Media server
server {
    listen 443 ssl;
    server_name $domain;
    
    ssl_certificate /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem;
    
    # SSL optimization
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Root directory for media files
    root /usr/share/nginx/html;
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Audio files
    location ~* ^/audio/.+\.(mp3|mid|midi|wav|ogg|m4a)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Range" always;
        
        # Enable range requests for audio seeking
        add_header Accept-Ranges bytes;
    }
    
    # Image files
    location ~* ^/images/.+\.(jpg|jpeg|png|gif|webp|svg|ico)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
    }
    
    # Root path - serve a simple index page
    location = / {
        return 200 "Advent Hymnals Media Server\n";
        add_header Content-Type text/plain;
    }
    
    # Block access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Block access to backup files
    location ~ ~\$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # 404 for other paths
    location / {
        return 404 "File not found\n";
        add_header Content-Type text/plain;
    }
}

EOF
  elif [[ "$domain" == "$PRIMARY_DOMAIN" ]]; then
    # Main application server block
    cat >> /etc/nginx/templates/default.conf.template << EOF
# Main application server
server {
    listen 443 ssl;
    server_name $domain;
    
    ssl_certificate /etc/letsencrypt/live/${PRIMARY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PRIMARY_DOMAIN}/privkey.pem;
    
    # SSL optimization
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    location / {
        proxy_pass http://advent-hymnals-web:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

EOF
  else
    # Generic domain block (if any other domains are added)
    cat >> /etc/nginx/templates/default.conf.template << EOF
# Generic server block for $domain
server {
    listen 443 ssl;
    server_name $domain;
    
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
  fi
done

echo "NGINX configuration generated successfully."