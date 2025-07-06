# Advent Hymnals - Deployment Repository

🎵 **Production deployment configuration for the Advent Hymnals digital hymnal collection**

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![GitHub Container Registry](https://img.shields.io/badge/GitHub_Container_Registry-2088FF?style=for-the-badge&logo=github&logoColor=white)](https://ghcr.io)
[![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org/)

## 📖 About

This repository contains the production deployment configuration for [Advent Hymnals](https://adventhymnals.org), a digital collection of Adventist hymnody spanning 160+ years of heritage. The application provides search capabilities across 13 complete hymnal collections with browseable metadata by meters, tunes, themes, authors, and composers.

### 🔗 Source Code
- **Main Repository**: [adventhymnals-monorepo](https://github.com/adventhymnals/adventhymnals-monorepo)
- **Container Registry**: [ghcr.io/adventhymnals/advent-hymnals-web](https://ghcr.io/adventhymnals/advent-hymnals-web)

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- A server with SSH access
- Domain name configured (optional but recommended)

### 1. Clone and Configure
```bash
# Clone this repository
git clone https://github.com/adventhymnals/advent-hymnals-web.git
cd advent-hymnals-web

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your configuration
```

### 2. Deploy
```bash
# Start the application
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f advent-hymnals-web
```

### 3. Access
- **Application**: `http://your-server-ip`
- **Health Check**: `http://your-server-ip/api/health`

## 📁 Repository Structure

```
advent-hymnals-web/
├── docker-compose.yml          # Production configuration
├── docker-compose.override.yml # Development overrides
├── .env.example               # Environment template
├── nginx/
│   └── nginx.conf            # Nginx reverse proxy config
├── scripts/
│   ├── deploy.sh            # Deployment script
│   ├── backup.sh            # Backup script
│   └── health-check.sh      # Health monitoring
├── logs/                    # Application logs (created at runtime)
├── data/                    # Persistent data (created at runtime)
└── README.md               # This file
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `NEXT_PUBLIC_GA_ID` | Google Analytics measurement ID | No | `G-JPQZVQ70L9` |
| `SITE_URL` | Primary site URL | Yes | `https://adventhymnals.org` |
| `NEXT_PUBLIC_SITE_URL` | Public site URL | Yes | `https://adventhymnals.org` |
| `GOOGLE_VERIFICATION` | Google Search Console verification | No | `abc123xyz` |
| `YANDEX_VERIFICATION` | Yandex verification code | No | `def456uvw` |

### Docker Compose Services

#### `advent-hymnals-web`
- **Image**: `ghcr.io/adventhymnals/advent-hymnals-web:latest`
- **Ports**: `80:3000` (HTTP), `443:3000` (HTTPS with SSL termination)
- **Health Check**: Built-in endpoint monitoring
- **Volumes**: Persistent data storage and log retention

#### `nginx-proxy` (Optional)
- **Image**: `nginx:alpine`
- **Purpose**: SSL termination, reverse proxy, rate limiting
- **Profile**: `nginx` (enable with `--profile nginx`)

## 🔧 Deployment Options

### Option 1: Direct Docker Compose (Recommended)
```bash
# Simple deployment
docker compose up -d
```

### Option 2: With Nginx Reverse Proxy
```bash
# With SSL termination and advanced features
docker compose --profile nginx up -d
```

### Option 3: Manual Container Run
```bash
# Pull and run manually
docker pull ghcr.io/adventhymnals/advent-hymnals-web:latest
docker run -d \
  --name advent-hymnals-web \
  -p 80:3000 \
  -e NEXT_PUBLIC_GA_ID=your-ga-id \
  -e SITE_URL=https://your-domain.com \
  -v hymnal-data:/app/data \
  ghcr.io/adventhymnals/advent-hymnals-web:latest
```

## 🏗️ CI/CD Integration

This repository automatically receives updated container images from the main source repository through GitHub Actions. The workflow:

1. **Source code changes** pushed to [main repository](https://github.com/adventhymnals/adventhymnals-monorepo)
2. **Automated build** creates optimized Docker image
3. **Image published** to GitHub Container Registry
4. **Deployment triggered** (manual or automated)

### Automated Deployment Setup

1. **Configure SSH access** on your server
2. **Set GitHub Secrets** in the main repository:
   ```
   DEPLOY_HOST=your-server-ip
   DEPLOY_USER=your-ssh-username
   DEPLOY_SSH_KEY=your-private-ssh-key
   NEXT_PUBLIC_GA_ID=your-google-analytics-id
   ```
3. **Push to main branch** triggers automatic deployment

## 📊 Monitoring and Maintenance

### Health Monitoring
```bash
# Check application health
curl http://localhost/api/health

# Monitor container status
docker compose ps

# View real-time logs
docker compose logs -f
```

### Performance Metrics
- **Health Check Endpoint**: `/api/health`
- **Built-in Analytics**: Google Analytics integration
- **Container Logs**: Application and access logs
- **Resource Usage**: Docker stats and monitoring

### Backup and Recovery
```bash
# Backup persistent data
docker run --rm \
  -v advent-hymnals-web_hymnal-data:/source \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/hymnal-data-$(date +%Y%m%d).tar.gz -C /source .

# Restore from backup
docker run --rm \
  -v advent-hymnals-web_hymnal-data:/target \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/hymnal-data-YYYYMMDD.tar.gz -C /target
```

## 🔐 Security

### Built-in Security Features
- **HTTPS enforcement** (with nginx profile)
- **Security headers** (CSP, HSTS, X-Frame-Options)
- **Rate limiting** (API and general requests)
- **Content Security Policy** configured for Google Analytics
- **Input validation** and sanitization

### SSL/TLS Configuration
When using the nginx profile, place your SSL certificates in:
- `./nginx/ssl/fullchain.pem` (certificate chain)
- `./nginx/ssl/privkey.pem` (private key)

## 🐛 Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check logs for errors
docker compose logs advent-hymnals-web

# Verify environment configuration
docker compose config
```

#### Port Conflicts
```bash
# Check port usage
sudo netstat -tulpn | grep :80

# Use different ports in docker-compose.yml
ports:
  - "8080:3000"  # Use port 8080 instead
```

#### Image Pull Failures
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Manual image pull
docker pull ghcr.io/adventhymnals/advent-hymnals-web:latest
```

#### Environment Variable Issues
```bash
# Check loaded environment
docker compose exec advent-hymnals-web env | grep NEXT_PUBLIC

# Restart with new environment
docker compose down && docker compose up -d
```

### Performance Issues
```bash
# Monitor resource usage
docker stats advent-hymnals-web

# Check application health
curl -s http://localhost/api/health | jq

# Analyze logs for errors
docker compose logs --tail=100 advent-hymnals-web | grep ERROR
```

## 📚 Additional Resources

### Documentation
- [Deployment Guide](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/docs/DEPLOYMENT.md)
- [Google Search Console Setup](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/docs/GOOGLE-SUBMISSION.md)
- [Development Setup](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/README.md)

### Support
- **Issues**: [Report issues](https://github.com/adventhymnals/adventhymnals-monorepo/issues)
- **Discussions**: [Community discussions](https://github.com/adventhymnals/adventhymnals-monorepo/discussions)
- **Source Code**: [Main repository](https://github.com/adventhymnals/adventhymnals-monorepo)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please see the [contributing guidelines](https://github.com/adventhymnals/adventhymnals-monorepo/blob/main/CONTRIBUTING.md) in the main repository.

---

**Advent Hymnals** - Preserving and sharing 160+ years of Adventist hymnody heritage through modern digital technology.

[![Built with Next.js](https://img.shields.io/badge/Built%20with-Next.js-black?style=flat-square&logo=next.js)](https://nextjs.org/)
[![Powered by Docker](https://img.shields.io/badge/Powered%20by-Docker-blue?style=flat-square&logo=docker)](https://www.docker.com/)
[![Deployed on GitHub](https://img.shields.io/badge/Deployed%20on-GitHub-green?style=flat-square&logo=github)](https://github.com/)