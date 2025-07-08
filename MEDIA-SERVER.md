# Media Server Integration

This document describes the media server integration for serving hymnal audio and image files at `media.adventhymnals.org`.

## Overview

The media server is integrated into the existing Advent Hymnals infrastructure and serves static media files (audio and images) with optimized caching and CORS support.

## Architecture

```
Internet → Nginx (Port 443) → Media Server Container
                            ↓
                        Data Volume (/opt/advent-hymnals/data/sources)
```

## Services

### media-server
- **Image**: `ghcr.io/adventhymnals/media-server:latest`  
- **Container**: `advent-hymnals-media`
- **Purpose**: Static file serving for audio and images
- **Health Check**: `/health` endpoint

### nginx
- **Updated**: Now includes media.adventhymnals.org subdomain support
- **SSL**: Shared certificate with main domain
- **Proxy**: Routes media.adventhymnals.org to media-server container

## File Structure

```
/opt/advent-hymnals/
├── docker-compose.yml           # Updated with media-server service
├── nginx/
│   ├── conf.d/default.conf     # Updated with media subdomain
│   ├── media-server.conf       # Media server nginx config
│   └── domains.txt             # Updated with media.adventhymnals.org
├── Dockerfile.media            # Media server container build
└── data/
    └── sources/                # Media files volume mount
        ├── audio/              # MP3 and MIDI files
        └── images/             # Hymnal page images
```

## Deployment

### Building Media Server Image

```bash
# Build media server image
docker build -f Dockerfile.media -t ghcr.io/adventhymnals/media-server:latest .

# Push to registry
docker push ghcr.io/adventhymnals/media-server:latest
```

### Updating SSL Certificates

The media subdomain uses the same SSL certificate as the main domain. To include the subdomain:

```bash
# Update certificate to include media subdomain
sudo certbot certonly --nginx -d adventhymnals.org -d www.adventhymnals.org -d media.adventhymnals.org
```

### Starting Services

```bash
cd /opt/advent-hymnals

# Pull latest images
docker-compose pull

# Start web application only
docker compose up -d

# Or start with media server (if image is available)
docker compose -f docker-compose.yml -f docker-compose.media.yml up -d

# Check health
curl https://adventhymnals.org/api/health
curl https://media.adventhymnals.org/health  # Only if media server is running
```

## API Endpoints

### Media Server (media.adventhymnals.org)

#### Health Check
```
GET /health
Response: "healthy"
```

#### Audio Files
```
GET /audio/{hymnal_id}/{filename}
Example: GET /audio/SDAH/1.mid
```

#### Image Files  
```
GET /images/{hymnal_id}/{filename}
Example: GET /images/SDAH/001.png
```

## Features

### Performance
- **Caching**: 1-year cache headers for static files
- **Compression**: Gzip for SVG and text files  
- **Range Requests**: Audio seeking support
- **SSL/HTTP2**: Encrypted and optimized delivery

### Security
- **CORS**: Configured for cross-origin access
- **Security Headers**: XSS protection, content type sniffing prevention
- **SSL**: TLS 1.2+ with secure cipher suites

### Monitoring
- **Health Checks**: Container and HTTP health monitoring
- **Logging**: Centralized nginx access and error logs
- **Metrics**: Ready for Prometheus/Grafana integration

## Environment Variables

```bash
# Media server image (optional override)
MEDIA_SERVER_IMAGE=ghcr.io/adventhymnals/media-server:latest
```

## Troubleshooting

### Check Container Status
```bash
docker-compose ps
docker-compose logs media-server
```

### Test Endpoints
```bash
# Health check
curl https://media.adventhymnals.org/health

# Test audio file
curl -I https://media.adventhymnals.org/audio/SDAH/1.mid

# Test image file  
curl -I https://media.adventhymnals.org/images/SDAH/001.png
```

### SSL Certificate Issues
```bash
# Check certificate validity
openssl s_client -connect media.adventhymnals.org:443 -servername media.adventhymnals.org

# Renew certificates
sudo certbot renew
```

### Volume Mount Issues
```bash
# Check data directory
ls -la /opt/advent-hymnals/data/sources/

# Verify volume mount
docker-compose exec media-server ls -la /usr/share/nginx/html/
```

## Integration with Main Application

The main Advent Hymnals web application has been updated to use the media server for serving audio and image files:

- Audio files: `https://media.adventhymnals.org/audio/...`
- Image files: `https://media.adventhymnals.org/images/...`

This provides:
- Better performance through optimized media serving
- Reduced load on the main application server
- Separate scaling for media vs. application traffic
- CDN-ready architecture for future optimization