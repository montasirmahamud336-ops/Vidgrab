# VidGrab VPS Deployment Guide

## Prerequisites

- Python 3.13+
- Git
- systemd (optional, for auto-start)
- Domain pointing to your VPS (optional)

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/yourusername/vidgrab.git /opt/vidgrab
cd /opt/vidgrab

# 2. Install Python dependencies
pip install -r backend/requirements.txt

# 3. (Optional) Configure paths via environment variables
export VIDGRAB_PORT=8000
export VIDGRAB_HOST=0.0.0.0
export VIDGRAB_WORKERS=4
export VIDGRAB_DOWNLOAD_DIR=/var/www/downloads
export VIDGRAB_ADS_CONFIG=/etc/vidgrab/ads_config.json
export VIDGRAB_DOWNLOAD_LOG=/var/log/vidgrab/downloads.json

# 4. Start the server
bash start.sh
```

The admin panel is available at `http://your-vps-ip:8000/admin/`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VIDGRAB_PORT` | `8000` | Server port |
| `VIDGRAB_HOST` | `0.0.0.0` | Bind address |
| `VIDGRAB_WORKERS` | `4` | Gunicorn worker count |
| `VIDGRAB_DOWNLOAD_DIR` | `~/Downloads` | Download output directory |
| `VIDGRAB_ADS_CONFIG` | `./ads_config.json` | Ads config file path |
| `VIDGRAB_DOWNLOAD_LOG` | `./downloads_log.json` | Download log file path |

## Run as a Service (systemd)

```bash
# 1. Copy service file
sudo cp vidgrab.service /etc/systemd/system/vidgrab.service

# 2. Edit paths if needed
sudo nano /etc/systemd/system/vidgrab.service

# 3. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable vidgrab
sudo systemctl start vidgrab

# 4. Check status
sudo systemctl status vidgrab

# 5. View logs
sudo journalctl -u vidgrab -f
```

## Using uvicorn (simpler, no gunicorn)

```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

## Using a Reverse Proxy (Nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## First-Time Setup

1. Open `http://your-vps-ip:8000/admin/` in your browser
2. Login with default password: `admin123`
3. Go to **Settings** and change the admin password immediately
4. Configure your ads in the **Banners** and **Side Banners** sections

## Important Notes

- Default password is `admin123` — **change it immediately** after first login
- The admin panel (`/admin/`) is a static export served by FastAPI — no separate Node.js server needed
- All API calls use the same origin (`window.location.origin`) — no manual backend URL configuration required
- Download tracking data is stored in `downloads_log.json`
- Ads configuration is stored in `ads_config.json`
