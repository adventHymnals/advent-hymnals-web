# Advent Hymnals - Traefik Deployment

🎵 **Production deployment configuration for the Advent Hymnals digital hymnal collection using Traefik**

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![GitHub Container Registry](https://img.shields.io/badge/GitHub_Container_Registry-2088FF?style=for-the-badge&logo=github&logoColor=white)](https://ghcr.io)
[![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org/)
[![Traefik](https://img.shields.io/badge/Traefik-24A1C1?style=for-the-badge&logo=traefik&logoColor=white)](https://traefik.io/)

## 📖 About

This repository contains the production deployment configuration for [Advent Hymnals](https://adventhymnals.org), a digital collection of Adventist hymnody spanning 160+ years of heritage. The application provides search capabilities across 13 complete hymnal collections with browseable metadata by meters, tunes, themes, authors, and composers.

**New in this version**: Complete **Traefik integration** replaces nginx for automatic SSL/TLS certificate management, modern reverse proxy features, and simplified deployment.

### 🔗 Source Code
- **Main Repository**: [adventhymnals-monorepo](https://github.com/adventhymnals/adventhymnals-monorepo)  
- **Container Registry**: [ghcr.io/adventhymnals/advent-hymnals-web](https://ghcr.io/adventhymnals/advent-hymnals-web)

## 🏗️ Architecture Overview

The deployment consists of three main services:

1. **🚦 Traefik** - Modern reverse proxy with automatic SSL/TLS from Let's Encrypt
2. **🌐 Advent Hymnals Web** - Main Next.js application 
3. **📁 Media Server** - Dedicated service for serving hymnal files and media content

### Features

- ✅ **Automatic SSL/TLS** with Let's Encrypt (HTTP/HTTPS challenge)
- ✅ **HTTP to HTTPS redirection** 
- ✅ **Traefik Dashboard** with basic authentication
- ✅ **Health checks** for all services
- ✅ **CORS handling** for media server
- ✅ **Log aggregation** in structured directories
- ✅ **Data persistence** with bind mounts
- ✅ **Multi-domain support** (main site + media subdomain)

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- **GitHub CLI (`gh`)** installed and authenticated
- Domain name pointing to your server
- Ports 80, 443, and 8080 accessible

### 1. Clone and Setup

```bash
# Clone this repository
git clone https://github.com/adventhymnals/advent-hymnals-web.git
cd advent-hymnals-web

# Copy and configure environment
cp .env.example .env
nano .env  # Edit with your actual values
```

### 2. Login to GitHub Container Registry

```bash
# Authenticate with GitHub CLI (if not already done)
gh auth login

# Login to GitHub Container Registry using automated script
./docker-login.sh
```

### 3. Start the Services

```bash
# Start all services with Traefik
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Access Your Services

Once deployed, you can access:

- **🌐 Main website**: `https://yourdomain.com`
- **📁 Media server**: `https://media.yourdomain.com`  
- **🚦 Traefik dashboard**: `https://traefik.yourdomain.com`

## ⚙️ Environment Configuration

Edit the `.env` file with your specific values:

### 🔧 Required Variables

```bash
# Your primary domain name
DOMAIN=adventhymnals.org

# Email for Let's Encrypt certificate registration  
ACME_EMAIL=admin@adventhymnals.org

# Traefik dashboard authentication (generate with htpasswd)
TRAEFIK_AUTH=admin:$$apr1$$8EVjn/nj$$GiLUZqcbuBMBdmvfX9PyE1
```

### 🎯 Optional Variables

```bash
# Custom Docker images
ADVENT_HYMNALS_IMAGE=ghcr.io/adventhymnals/advent-hymnals-web:latest
MEDIA_SERVER_IMAGE=ghcr.io/adventhymnals/media-server:latest

# Data storage paths (absolute paths recommended)
DATA_PATH=/opt/advent-hymnals/data
MEDIA_PATH=/opt/advent-hymnals/data/sources

# Analytics and verification
NEXT_PUBLIC_GA_ID=G-JPQZVQ70L9
GOOGLE_VERIFICATION=your-google-verification-code
YANDEX_VERIFICATION=your-yandex-verification-code
```

## 📁 Repository Structure

```
advent-hymnals-web/
├── docker-compose.yml      # Traefik-based production config
├── .env.example           # Environment template  
├── .env                   # Your environment (create from example)
├── docker-login.sh        # GitHub Container Registry login script
├── logs/                  # Log files
│   ├── app/              # Application logs
│   ├── media/            # Media server logs
│   └── traefik/          # Traefik logs
├── data/                  # Application data
│   └── sources/          # Media files
└── README.md              # This file
```

## 🔐 SSL Certificate Management

Traefik automatically handles SSL certificates using Let's Encrypt:

- **🔄 Automatic generation** for all configured domains
- **⏰ Automatic renewal** before expiration  
- **🏆 TLS challenge validation** (port 443 must be accessible)
- **💾 Persistent storage** in Docker volume `traefik-letsencrypt`

## 🛡️ Security Features

### Traefik Dashboard Protection

The Traefik dashboard is protected with HTTP Basic Authentication. Generate a secure password hash:

```bash
# Install htpasswd (if not available)
sudo apt install apache2-utils  # Ubuntu/Debian
# OR
brew install httpie             # macOS

# Generate htpasswd hash (escape $ characters for Docker Compose)
echo $(htpasswd -nb admin your-secure-password) | sed -e s/\\$/\\$\\$/g
```

Add the output to your `.env` file as `TRAEFIK_AUTH`.

### CORS Configuration

The media server includes CORS headers configured to:
- ✅ Allow access from your main domain
- ❌ Prevent unauthorized cross-origin requests  
- 🔧 Support preflight OPTIONS requests

## 📊 Monitoring and Maintenance

### View Logs

```bash
# All services
docker-compose logs -f

# Specific services
docker-compose logs -f advent-hymnals-web
docker-compose logs -f media-server  
docker-compose logs -f traefik
```

### Health Checks

All services include comprehensive health checks:

```bash
# Check overall service health
docker-compose ps

# Inspect specific service health
docker inspect advent-hymnals-web --format='{{.State.Health.Status}}'

# Test endpoints directly
curl -f http://localhost:3000/health  # App health (internal)
curl -f https://yourdomain.com/      # External access test
```

### Updates

To update to new application versions:

```bash
# 1. Login to registry (if token expired)
./docker-login.sh

# 2. Pull latest images
docker-compose pull

# 3. Restart services with new images
docker-compose up -d

# 4. Verify deployment
docker-compose ps
```

## 🐛 Troubleshooting

### 🔍 Common Issues

#### 1. Certificate Generation Fails
```bash
# Symptoms: SSL errors, "certificate not found" 
# Solutions:
- Ensure ports 80 and 443 are open and accessible
- Check DNS: your domain should point to the server IP
- Verify ACME_EMAIL is a valid email address
- Check Traefik logs: docker-compose logs traefik
```

#### 2. Services Won't Start  
```bash
# Check environment variables
docker-compose config

# Verify data directories exist with correct permissions
ls -la logs/ data/

# Review startup logs
docker-compose logs
```

#### 3. GitHub Container Registry Access Denied
```bash
# Re-authenticate with GitHub CLI
gh auth login

# Check GitHub token permissions (needs read:packages)
gh auth status

# Re-run Docker login
./docker-login.sh
```

#### 4. Traefik Dashboard Inaccessible
```bash
# Verify dashboard subdomain in DNS
nslookup traefik.yourdomain.com

# Check basic auth configuration  
echo "$TRAEFIK_AUTH" | base64 -d

# Test without auth (temporarily remove middleware)
```

### 🔧 Debug Commands

```bash
# Check Docker networks
docker network ls | grep advent

# Inspect Traefik configuration
docker exec advent-hymnals-traefik traefik version

# Test internal connectivity
docker exec advent-hymnals-web wget -qO- http://localhost:3000/health

# Check certificate status  
docker exec advent-hymnals-traefik ls -la /letsencrypt/acme.json

# Monitor resource usage
docker stats --no-stream
```

## 💾 Data Backup

Important locations to backup regularly:

```bash
# 1. SSL certificates (automatic backup recommended)
docker volume create --name backup-letsencrypt
docker run --rm -v traefik-letsencrypt:/source -v backup-letsencrypt:/backup alpine cp -r /source /backup

# 2. Application data
tar czf advent-hymnals-backup-$(date +%Y%m%d).tar.gz ./data/

# 3. Logs (optional, for debugging)
tar czf logs-backup-$(date +%Y%m%d).tar.gz ./logs/

# 4. Configuration
tar czf config-backup-$(date +%Y%m%d).tar.gz .env docker-compose.yml
```

## 🚀 Production Deployment Best Practices

For production deployment:

1. **🔒 Security**: Use strong passwords for `TRAEFIK_AUTH`
2. **📊 Monitoring**: Configure log aggregation and alerting  
3. **💾 Backups**: Automate data and certificate backups
4. **🔄 Updates**: Set up automated security updates
5. **🏋️ Resources**: Set resource limits in docker-compose.yml if needed
6. **🔥 Firewalls**: Configure UFW or iptables appropriately
7. **📈 Monitoring**: Consider adding Prometheus/Grafana

### Example Resource Limits

```yaml
services:
  advent-hymnals-web:
    # ... other configuration
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

## 🏗️ Development Mode

For development and testing, you can:

1. **Add port mappings** for direct access:
   ```yaml
   advent-hymnals-web:
     ports:
       - "3000:3000"  # Direct access
   ```

2. **Mount source code** (if developing locally):
   ```yaml
   advent-hymnals-web:
     volumes:
       - ./src:/app/src  # Live code changes
   ```

3. **Set development environment**:
   ```bash
   NODE_ENV=development
   ```

## 📚 Additional Resources

### 📖 Documentation
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Main Advent Hymnals Repository](https://github.com/adventhymnals/adventhymnals-monorepo)

### 🆘 Support
- **🐛 Issues**: [Report issues](https://github.com/adventhymnals/adventhymnals-monorepo/issues)
- **💬 Discussions**: [Community discussions](https://github.com/adventhymnals/adventhymnals-monorepo/discussions)  
- **📚 Source Code**: [Main repository](https://github.com/adventhymnals/adventhymnals-monorepo)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please see the [contributing guidelines](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/CONTRIBUTING.md) in the main repository.

---

**Advent Hymnals** - Preserving and sharing 160+ years of Adventist hymnody heritage through modern digital technology, now with **Traefik-powered deployment**.

[![Built with Next.js](https://img.shields.io/badge/Built%20with-Next.js-black?style=flat-square&logo=next.js)](https://nextjs.org/)
[![Powered by Docker](https://img.shields.io/badge/Powered%20by-Docker-blue?style=flat-square&logo=docker)](https://www.docker.com/)
[![Deployed with Traefik](https://img.shields.io/badge/Deployed%20with-Traefik-24A1C1?style=flat-square&logo=traefik)](https://traefik.io/)
[![GitHub Container Registry](https://img.shields.io/badge/Images%20on-GHCR-green?style=flat-square&logo=github)](https://ghcr.io/)